package com.countsend.countsend

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Path
import android.graphics.Rect
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class CountdownAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "CountSendAccessibility"
        var instance: CountdownAccessibilityService? = null
            private set

        fun isRunning(): Boolean = instance != null
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.i(TAG, "CountdownAccessibilityService connected and ready")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Monitored for window transitions if needed
    }

    override fun onInterrupt() {
        Log.w(TAG, "CountdownAccessibilityService interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.i(TAG, "CountdownAccessibilityService destroyed")
    }

    /**
     * Injects the countdown text into the focused/editable input field
     * and automatically clicks or touch-taps the Send button.
     * If customTapX and customTapY are provided (> 0), it dispatches the tap directly
     * to that exact user-calibrated coordinate!
     */
    fun typeAndSend(
        text: String,
        autoSend: Boolean,
        customTapX: Float? = null,
        customTapY: Float? = null,
        onResult: ((Boolean, String) -> Unit)? = null
    ) {
        mainHandler.post {
            val rootNode = rootInActiveWindow
            if (rootNode == null) {
                Log.w(TAG, "Active window root node is null")
                onResult?.invoke(false, "No active window found on screen")
                return@post
            }

            // 1. Locate the input field
            val inputNode = findInputNode(rootNode)
            if (inputNode == null) {
                Log.w(TAG, "Could not find any editable/focused input field")
                onResult?.invoke(false, "No input field found. Tap into the chat box first.")
                return@post
            }

            val inputRect = Rect()
            inputNode.getBoundsInScreen(inputRect)
            Log.i(TAG, "Target input field located at bounds: $inputRect, class: ${inputNode.className}")

            // 2. Inject text into the field
            val textSuccess = setNodeText(inputNode, inputRect, text)
            if (!textSuccess) {
                Log.w(TAG, "Failed to set text in input node")
                onResult?.invoke(false, "Failed to inject text into input field")
                return@post
            }

            Log.i(TAG, "Text injected successfully into input: $text")

            if (!autoSend) {
                onResult?.invoke(true, "Text injected (Manual send mode)")
                return@post
            }

            // 3. Compute dynamic Send target coordinates
            val inputCenterY = if (inputRect.height() > 0) inputRect.centerY().toFloat() else 2150f
            val targetX: Float
            val targetY: Float

            if (customTapX != null && customTapX > 0) {
                targetX = customTapX
                // In messaging apps (WhatsApp, Instagram, Telegram), the send button is always
                // vertically in line with the chat text box.
                // If keyboard opened/closed, the composer shifted vertically, so we track inputCenterY.
                targetY = if (customTapY != null && customTapY > 0 && Math.abs(customTapY - inputCenterY) < 140) {
                    customTapY
                } else {
                    Log.i(TAG, "Adapting Send button Y to current input center: $inputCenterY (pinned was $customTapY)")
                    inputCenterY
                }
            } else {
                targetX = (inputRect.right + 70).coerceAtMost(1020).toFloat()
                targetY = inputCenterY
            }

            Log.i(TAG, "Executing Send click at target coordinates ($targetX, $targetY)")

            // Wait 280ms for chat UI to morph microphone/attachment icon into Send button
            mainHandler.postDelayed({
                val currentRoot = rootInActiveWindow ?: rootNode

                // Step A: Search for clickable node at or near target coordinates
                val sendNode = findNodeAtPoint(currentRoot, targetX.toInt(), targetY.toInt())
                    ?: findSendButton(currentRoot, inputRect)

                var nodeClicked = false
                if (sendNode != null) {
                    val buttonRect = Rect()
                    sendNode.getBoundsInScreen(buttonRect)
                    Log.i(TAG, "Found Send button node: class=${sendNode.className}, bounds=$buttonRect, performing ACTION_CLICK")
                    nodeClicked = sendNode.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    if (!nodeClicked && sendNode.parent != null) {
                        nodeClicked = sendNode.parent.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    }
                }

                // Step B: Dispatch hardware touch gesture directly to the coordinates
                Log.i(TAG, "Dispatching primary hardware touch tap to ($targetX, $targetY)")
                val gestureSuccess = dispatchGestureClick(targetX, targetY)

                // Step C: Follow-up tap 180ms later for apps with slower frame transitions (e.g. Instagram Litho/Compose)
                mainHandler.postDelayed({
                    dispatchGestureClick(targetX, targetY)
                }, 180)

                if (nodeClicked || gestureSuccess) {
                    onResult?.invoke(true, "Message sent via pin ($targetX, $targetY)")
                } else {
                    onResult?.invoke(false, "Send click failed at ($targetX, $targetY)")
                }
            }, 280)
        }
    }

    /**
     * Tries to find and tap the send button, retrying if the app's UI is still animating
     * (e.g. Instagram/WhatsApp morphing voice icon into send button).
     */
    private fun attemptSendClickWithRetries(
        inputRect: Rect,
        retryCount: Int,
        onResult: ((Boolean, String) -> Unit)?
    ) {
        val delayMs = if (retryCount == 0) 250L else 300L

        mainHandler.postDelayed({
            val currentRoot = rootInActiveWindow
            if (currentRoot == null) {
                if (retryCount < 2) {
                    attemptSendClickWithRetries(inputRect, retryCount + 1, onResult)
                } else {
                    onResult?.invoke(true, "Message typed (Window changed)")
                }
                return@postDelayed
            }

            // Look for send button candidate (must be on right side of input field!)
            val sendNode = findSendButton(currentRoot, inputRect)

            if (sendNode != null) {
                val buttonRect = Rect()
                sendNode.getBoundsInScreen(buttonRect)
                Log.i(TAG, "Found Send button target at bounds: $buttonRect, class: ${sendNode.className}")

                performClickOnNode(sendNode, buttonRect)
                onResult?.invoke(true, "Message typed & Send tapped!")
            } else if (retryCount < 2) {
                // UI may still be updating, retry once more
                Log.d(TAG, "Send button not yet found, retrying in 300ms... (attempt ${retryCount + 1})")
                attemptSendClickWithRetries(inputRect, retryCount + 1, onResult)
            } else {
                // Final fallback: Tap the area directly to the right of the input field
                // (where the send button is always positioned in chat apps)
                if (inputRect.right > 0 && inputRect.height() > 0) {
                    val fallbackX = (inputRect.right + 70).coerceAtMost(1020).toFloat()
                    val fallbackY = inputRect.centerY().toFloat()
                    Log.i(TAG, "Using positional send tap fallback at ($fallbackX, $fallbackY)")
                    dispatchGestureClick(fallbackX, fallbackY)
                    onResult?.invoke(true, "Message typed & Send tapped (Positional)")
                } else {
                    Log.w(TAG, "Send button could not be identified after retries")
                    onResult?.invoke(true, "Message typed (Tap send manually)")
                }
            }
        }, delayMs)
    }

    private fun findInputNode(root: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        val focused = findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
        if (focused != null && isEditableNode(focused)) {
            return focused
        }

        val focusedDFS = findFocusedEditableDFS(root)
        if (focusedDFS != null) {
            return focusedDFS
        }

        return findAnyEditableDFS(root)
    }

    private fun isEditableNode(node: AccessibilityNodeInfo): Boolean {
        val className = node.className?.toString() ?: ""
        return node.isEditable ||
                className.contains("EditText", ignoreCase = true) ||
                className.contains("TextInput", ignoreCase = true) ||
                (node.isFocusable && className.contains("TextView", ignoreCase = true) && node.text != null)
    }

    private fun findFocusedEditableDFS(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (node.isFocused && isEditableNode(node)) {
            return node
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val result = findFocusedEditableDFS(child)
            if (result != null) return result
        }
        return null
    }

    private fun findAnyEditableDFS(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (isEditableNode(node)) {
            return node
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val result = findAnyEditableDFS(child)
            if (result != null) return result
        }
        return null
    }

    /**
     * Sets text in the target node with focus restoration and clipboard paste fallback.
     */
    private fun setNodeText(node: AccessibilityNodeInfo, bounds: Rect, text: String): Boolean {
        if (!node.isFocused) {
            node.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
            node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        }

        val arguments = Bundle().apply {
            putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
        }
        var success = node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)

        if (!success && bounds.width() > 0 && bounds.height() > 0) {
            dispatchGestureClick(bounds.centerX().toFloat(), bounds.centerY().toFloat())
            Thread.sleep(80)
            node.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
            success = node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
        }

        if (!success) {
            try {
                val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                val clip = ClipData.newPlainText("CountSend", text)
                clipboard.setPrimaryClip(clip)
                node.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
                success = node.performAction(AccessibilityNodeInfo.ACTION_PASTE)
            } catch (e: Exception) {
                Log.e(TAG, "Clipboard paste fallback error", e)
            }
        }

        return success
    }

    /**
     * Locates the Send button. CRITICAL REQUIREMENT: Must be positioned on the RIGHT side
     * of the input field (nodeRect.centerX() >= inputRect.centerX()), never on the left!
     */
    private fun findSendButton(root: AccessibilityNodeInfo, inputRect: Rect): AccessibilityNodeInfo? {
        val sendKeywords = listOf(
            "send", "envoyer", "enviar", "invia", "senden",
            "envoie", "отправить", "भेजें", "send message", "send direct"
        )
        val idKeywords = listOf(
            "send", "btn_send", "send_button", "send_btn",
            "conversation_send_button", "entry_send", "composer_send"
        )

        // Strategy 1: Search for send keywords BUT strictly filter to right side of input!
        val keywordMatch = searchSendNodeRecursive(root, sendKeywords, idKeywords, inputRect)
        if (keywordMatch != null) {
            return resolveBestClickableTarget(keywordMatch)
        }

        // Strategy 2: Look for any actionable button directly to the right of the input box
        return searchPositionalSendButton(root, inputRect)
    }

    private fun searchSendNodeRecursive(
        node: AccessibilityNodeInfo,
        sendKeywords: List<String>,
        idKeywords: List<String>,
        inputRect: Rect
    ): AccessibilityNodeInfo? {
        val nodeRect = Rect()
        node.getBoundsInScreen(nodeRect)

        // Ensure this node is located to the right of the input field or below it,
        // NEVER to the left where camera/gallery/sticker icons are!
        val isNotLeftOfInput = inputRect.isEmpty || nodeRect.centerX() >= inputRect.centerX()

        if (isNotLeftOfInput && nodeRect.width() > 0 && nodeRect.height() > 0) {
            val desc = node.contentDescription?.toString()?.lowercase() ?: ""
            val text = node.text?.toString()?.lowercase() ?: ""
            val viewId = node.viewIdResourceName?.lowercase() ?: ""

            for (kw in sendKeywords) {
                if (desc.contains(kw) || text.contains(kw)) {
                    return node
                }
            }
            for (idKw in idKeywords) {
                if (viewId.contains(idKw)) {
                    return node
                }
            }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val match = searchSendNodeRecursive(child, sendKeywords, idKeywords, inputRect)
            if (match != null) return match
        }

        return null
    }

    private fun resolveBestClickableTarget(node: AccessibilityNodeInfo): AccessibilityNodeInfo {
        if (node.isClickable) return node

        var current: AccessibilityNodeInfo? = node.parent
        while (current != null) {
            if (current.isClickable) {
                return current
            }
            current = current.parent
        }
        return node
    }

    private fun searchPositionalSendButton(root: AccessibilityNodeInfo, inputRect: Rect): AccessibilityNodeInfo? {
        if (inputRect.isEmpty) return null

        var bestNode: AccessibilityNodeInfo? = null
        var bestRightDistance = Int.MAX_VALUE

        fun scanForRightSibling(node: AccessibilityNodeInfo) {
            if (node.isClickable) {
                val nodeRect = Rect()
                node.getBoundsInScreen(nodeRect)

                val isVerticallyAligned = Math.abs(nodeRect.centerY() - inputRect.centerY()) < 150
                val isToRight = nodeRect.centerX() > inputRect.centerX()

                if (isVerticallyAligned && isToRight && nodeRect.width() > 0 && nodeRect.height() > 0) {
                    val dist = nodeRect.left - inputRect.right
                    if (dist >= -50 && dist < bestRightDistance) {
                        bestRightDistance = dist
                        bestNode = node
                    }
                }
            }

            for (i in 0 until node.childCount) {
                val child = node.getChild(i) ?: continue
                scanForRightSibling(child)
            }
        }

        scanForRightSibling(root)
        return bestNode
    }

    private fun performClickOnNode(node: AccessibilityNodeInfo, bounds: Rect): Boolean {
        var actionClicked = node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        if (!actionClicked && node.parent != null && node.parent.isClickable) {
            actionClicked = node.parent.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        }

        var gestureDispatched = false
        if (bounds.width() > 0 && bounds.height() > 0) {
            val tapX = bounds.centerX().toFloat()
            val tapY = bounds.centerY().toFloat()
            Log.i(TAG, "Dispatching hardware touch gesture to ($tapX, $tapY)")
            gestureDispatched = dispatchGestureClick(tapX, tapY)
        }

        return actionClicked || gestureDispatched
    }

    private fun findNodeAtPoint(root: AccessibilityNodeInfo, x: Int, y: Int): AccessibilityNodeInfo? {
        val rect = Rect()
        var bestNode: AccessibilityNodeInfo? = null

        fun traverse(node: AccessibilityNodeInfo) {
            node.getBoundsInScreen(rect)
            if (x >= rect.left - 25 && x <= rect.right + 25 && y >= rect.top - 25 && y <= rect.bottom + 25) {
                if (node.isClickable || node.className?.contains("Button") == true || node.className?.contains("ImageView") == true) {
                    bestNode = node
                }
                for (i in 0 until node.childCount) {
                    val child = node.getChild(i) ?: continue
                    traverse(child)
                }
            }
        }

        traverse(root)
        return bestNode
    }

    fun dispatchGestureClick(x: Float, y: Float, onComplete: (() -> Unit)? = null): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val path = Path().apply {
                moveTo(x, y)
                lineTo(x + 1f, y + 1f)
            }
            val stroke = GestureDescription.StrokeDescription(path, 0, 100)
            val gesture = GestureDescription.Builder().addStroke(stroke).build()
            return dispatchGesture(gesture, object : GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    super.onCompleted(gestureDescription)
                    Log.i(TAG, "Gesture touch tap executed successfully at ($x, $y)")
                    onComplete?.invoke()
                }

                override fun onCancelled(gestureDescription: GestureDescription?) {
                    super.onCancelled(gestureDescription)
                    Log.w(TAG, "Gesture touch tap was cancelled at ($x, $y)")
                    onComplete?.invoke()
                }
            }, null)
        }
        return false
    }
}
