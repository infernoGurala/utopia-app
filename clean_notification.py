import re

def clean_file():
    with open('lib/services/notification_service.dart', 'r') as f:
        content = f.read()
    
    # 1. Remove import
    content = content.replace("import 'package:utopia_app/widgets/notification_dialog.dart';\n", "")
    
    # 2. Background handler
    content = content.replace("await NotificationService.persistPendingRemoteMessage(message);", "")
    
    # 3. Firestore saves
    content = content.replace("unawaited(_saveNotificationToFirestore(message));\n", "")
    content = content.replace("unawaited(_saveNotificationToFirestore(initialMessage));\n", "")
    
    # 4. showNotificationDialog
    content = content.replace("showNotificationDialog(title: title, body: body);", "")
    content = content.replace("showNotificationDialog(title: 'Personal test notification', body: trimmed);", "")
    content = content.replace("showNotificationDialog(title: resolvedTitle, body: resolvedBody);", "")

    # 5. _handleRemoteMessageInteraction fix
    content = re.sub(
        r'return _removePendingNotification\([^)]+\)\.then\(\s*\(_\)\s*=>\s*_handleNotificationInteraction\(',
        r'return _handleNotificationInteraction(',
        content
    )
    content = content.replace(
        "data: Map<String, dynamic>.from(message.data),\n      ),\n    );",
        "data: Map<String, dynamic>.from(message.data),\n    );"
    )

    # 6. Delete methods
    methods_to_delete = [
        'static Future<void> persistPendingRemoteMessage(RemoteMessage message) async {',
        'static Future<void> maybeShowPendingDialog() async {',
        'static Future<void> _saveNotificationToFirestore(',
        'static bool _shouldQueuePendingNotification({',
        'static Future<Map<String, dynamic>?> _consumePendingNotification() async {',
        'static Future<void> _removePendingNotification({',
        'static bool _matchesPendingNotification(',
        'static Future<void> _syncPendingNotificationToFirestore({'
    ]
    
    def remove_method(code, method_sig):
        start = code.find(method_sig)
        if start == -1: return code
        
        brace_count = 0
        in_string = False
        idx = start
        found_first_brace = False
        
        while idx < len(code):
            c = code[idx]
            if c == '"' or c == "'":
                in_string = not in_string
            if not in_string:
                if c == '{':
                    brace_count += 1
                    found_first_brace = True
                elif c == '}':
                    brace_count -= 1
                    if found_first_brace and brace_count == 0:
                        return code[:start] + code[idx+1:]
            idx += 1
        return code
    
    for m in methods_to_delete:
        content = remove_method(content, m)
        
    # 7. Clean up sendPersonalTestNotification firestore block
    test_fire = """    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': 'Personal test notification',
        'body': trimmed,
        'type': 'personal_test',
        'receivedAt': FieldValue.serverTimestamp(),
        'read': false,
        'dialogPending': false,
        'uid': user.uid,
        'messageId': 'personal-test-${DateTime.now().millisecondsSinceEpoch}',
      });
    } catch (e) {
      return;
    }"""
    content = content.replace(test_fire, "")

    # 8. Clean up sendPersonalMorningNotification firestore block
    morn_fire = """    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': resolvedTitle,
        'body': resolvedBody,
        'type': 'morning_notification',
        'receivedAt': FieldValue.serverTimestamp(),
        'read': false,
        'dialogPending': false,
        'uid': user.uid,
        'messageId':
            'personal-morning-${DateTime.now().millisecondsSinceEpoch}',
      });
    } catch (e) {
      return;
    }"""
    content = content.replace(morn_fire, "")

    with open('lib/services/notification_service.dart', 'w') as f:
        f.write(content)

clean_file()
