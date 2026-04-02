const Map<String, String> appStringsEn = {
  'app_title': 'Bot Creator',

  // Onboarding
  'onboarding_welcome_title': 'Welcome to Bot Creator',
  'onboarding_welcome_desc':
      'Create your first Discord bot in 3 simple steps. We\'ll guide you through each step.',
  'onboarding_welcome_start': 'Get Started',
  'onboarding_welcome_skip': 'Skip',

  'onboarding_create_title': 'Step 1: Create a Bot',
  'onboarding_create_desc': 'Get your Discord token',
  'onboarding_create_steps':
      '1. Go to Discord Developer Portal\n2. Create a new app\n3. Copy the bot token\n4. Paste it below',
  'onboarding_create_tip':
      '💡 Tip: Never share your token! It gives full access to your bot.',
  'onboarding_create_tutorial': 'Tutorial: How to get a token',
  'onboarding_create_button': 'Continue',

  'onboarding_command_title': 'Step 2: Add a Command',
  'onboarding_command_desc': 'Create your first command',
  'onboarding_command_text':
      'Commands are the heart of your bot. They allow users to interact with your bot via Discord.',
  'onboarding_command_example': 'Example:\n/hello → Bot replies "Hello! 👋"',
  'onboarding_command_button': 'Continue',

  'onboarding_start_title': 'Step 3: Start the Bot',
  'onboarding_start_desc': 'Launch your bot!',
  'onboarding_start_text':
      'Click the "Start" button on your bot card. Then test your command in Discord!',
  'onboarding_start_tip':
      '✨ Great! You\'ve created your first Discord bot. You can now add more commands and customize it!',
  'onboarding_start_button': 'Continue',

  'onboarding_success_title': 'Congratulations! 🎉',
  'onboarding_success_desc': 'Your Discord bot is ready to go!',
  'onboarding_success_whatsnext': 'What\'s next?',
  'onboarding_success_tip1': 'Add more commands',
  'onboarding_success_tip2': 'Create workflows',
  'onboarding_success_tip3': 'Backup your data',
  'onboarding_success_button': 'Start!',

  // App UI
  'app_create_new': 'Create a new App',
  'app_create_page_title': 'Create a bot',
  'app_create_hero_title': 'Connect your Discord bot',
  'app_create_hero_desc':
      'A guided setup to open the right pages, copy your token and import the bot safely.',
  'app_resources_title': 'Guided setup',
  'app_resources_desc':
      'These actions open the official pages you need before saving your bot here.',
  'app_open_discord_portal': 'Open Discord Developer Portal',
  'app_open_discord_portal_desc':
      'Create your application and enable the bot section.',
  'app_open_token_tutorial': 'Read the token tutorial',
  'app_open_token_tutorial_desc':
      'A step-by-step guide to generate and copy your bot token.',
  'app_external_link_badge': 'External link',
  'app_token_section_title': 'Paste your bot token',
  'app_token_section_desc':
      'Once the token is copied, paste it below to add your bot to the app.',
  'app_token_field_helper': 'Paste the token exactly as provided by Discord.',
  'app_token_security_hint':
      'Keep this token private. Anyone with it can control your bot.',
  'app_show_token': 'Show token',
  'app_hide_token': 'Hide token',
  'app_save_bot': 'Add bot',
  'app_open_link_error': 'Unable to open this external page.',
  'app_how_to_create_token': 'How to create a Bot Token?',
  'app_bot_token': 'Bot Token',
  'app_enter_token': 'Enter your bot token here',
  'app_note':
      'Note: You need to create a new App in the Discord Developer Portal and get your bot token.',
  'app_save': 'Save Changes',
  'app_no_apps': 'No applications found',
  'app_loading_error': 'Loading error',
  'app_create_button': 'Create a bot',

  'home_tab': 'Home',
  'commands_tab': 'Commands',
  'commands_tab_short': 'Cmd',
  'globals_tab': 'Globals',
  'globals_tab_short': 'Vars',
  'workflows_tab': 'Workflows',
  'workflows_tab_short': 'Flow',
  'scheduler_tab': 'Scheduler',
  'scheduler_tab_short': 'Sched',
  'emojis_tab': 'Emojis',
  'emojis_tab_short': 'Emoji',
  'emojis_title': 'Application Emojis',
  'emojis_empty': 'No emojis yet. Upload one to get started.',
  'emojis_upload': 'Upload Emoji',
  'emojis_upload_name_hint': 'Emoji name (letters, numbers, _)',
  'emojis_upload_pick_image': 'Pick Image',
  'emojis_delete_confirm_title': 'Delete Emoji',
  'emojis_delete_confirm_body':
      'Delete :{name}: ? This action cannot be undone.',
  'emojis_rename_title': 'Rename Emoji',
  'emojis_rename_hint': 'New name',
  'emojis_loading_error': 'Failed to load emojis',
  'emojis_upload_error': 'Upload failed: {error}',
  'emojis_delete_error': 'Delete failed: {error}',
  'emojis_rename_error': 'Rename failed: {error}',
  'settings_tab': 'Settings',
  'more_tab': 'More',
  'quick_access_title': 'Quick Access',
  'more_options_title': 'More Options',
  'no_more_options': 'No other options available',
  'settings_theme_switch_light': 'Switch to light mode',
  'settings_theme_switch_dark': 'Switch to dark mode',
  'settings_appearance_title': 'Appearance & language',
  'settings_language_title': 'Language',
  'settings_language_desc': 'Choose the language used by the app.',
  'settings_language_system': 'Automatic (device)',
  'settings_language_updated': 'Language updated',
  'settings_debug_title': 'Debug tools',
  'settings_debug_desc':
      'Reset local preferences or replay onboarding for testing.',
  'settings_reset_preferences': 'Reset preferences',
  'settings_reset_preferences_desc':
      'Reset theme, language and onboarding progress.',
  'settings_replay_onboarding': 'Replay onboarding',
  'settings_replay_onboarding_desc':
      'Reset onboarding and launch it again now.',
  'settings_preferences_reset_done': 'Preferences reset',
  'settings_backup_restore_title': 'Backup and Restore',
  'settings_backup_restore_desc':
      'Manage your data synchronization with Google Drive',
  'settings_snapshot_preview_title': 'Snapshot Preview',
  'settings_snapshot_id': 'ID: {id}',
  'settings_snapshot_label': 'Label: {label}',
  'settings_snapshot_created_at': 'Created: {date}',
  'settings_snapshot_files_size': 'Files: {count} • Size: {size}',
  'settings_snapshot_apps_count': 'Apps: {count}',
  'settings_snapshot_apps_list': 'Apps in this snapshot',
  'settings_snapshot_no_metadata': 'No app metadata available.',
  'settings_snapshot_delete_loading': 'Deleting snapshot…',
  'settings_snapshot_deleted': 'Snapshot deleted',
  'settings_snapshot_restore_loading': 'Restoring snapshot…',
  'settings_restore_snapshot': 'Restore This Snapshot',
  'settings_diagnostics_dialog_title': 'Startup Diagnostics',
  'settings_diagnostics_copied': 'Diagnostics copied to clipboard',
  'settings_drive_title': 'Google Drive Connection',
  'settings_drive_desc': 'Connect your Google Drive account to sync your data',
  'settings_drive_connect_loading': 'Connecting to Google Drive…',
  'settings_drive_connected': 'Connected to Google Drive',
  'settings_drive_connect': 'Connect to Google Drive',
  'settings_drive_status_connected': 'Connected',
  'settings_drive_disconnect_loading': 'Disconnecting…',
  'settings_drive_disconnected': 'Disconnected from Google Drive',
  'settings_drive_disconnect': 'Disconnect',
  // Runner API (API only)
  'settings_runner_title': 'Runner API',
  'settings_runner_desc':
      'Connect the app to a Bot Creator Runner. Remote runners should stay on trusted '
      'networks and use a bearer token.',
  'settings_runner_url_hint': 'http://192.168.1.x:8080',
  'settings_runner_token_label': 'Runner API token',
  'settings_runner_token_hint': 'Bearer token (optional on localhost)',
  'settings_runner_save': 'Save settings',
  'settings_runner_clear': 'Clear',
  'settings_runner_saved': 'Runner settings saved',
  'settings_runner_cleared': 'Runner settings cleared',
  'settings_runner_url_save': 'Save URL',
  'settings_runner_url_clear': 'Clear',
  'settings_runner_url_saved': 'Runner URL saved',
  'settings_runner_url_cleared': 'Runner URL cleared',
  'settings_runner_check': 'Check connection',
  'settings_runner_connected': 'Runner reachable ✓',
  'settings_runner_auth_failed': 'Runner rejected the API token',
  'settings_runner_unreachable': 'Runner unreachable',
  'settings_runner_connecting': 'Checking connection…',
  'settings_runner_active': 'Active Runner API: {url}',
  'settings_runner_disable_temp': 'Temporarily disable Runner',
  'settings_runner_disable_temp_desc':
      'Keep Runner settings but force local mode until re-enabled.',
  'settings_runner_temporarily_disabled':
      'Runner temporarily disabled (local mode active)',
  'settings_runner_temporarily_disabled_saved': 'Runner temporarily disabled',
  'settings_runner_reenabled': 'Runner re-enabled',
  'settings_data_operations_title': 'Data Operations',
  'settings_export': 'Export',
  'settings_import': 'Import',
  'settings_export_app_data': 'Export App Data',
  'settings_import_app_data': 'Import App Data',
  'settings_export_loading': 'Exporting…',
  'settings_import_loading': 'Importing…',
  'settings_recovery_title': 'Recovery Pro',
  'settings_enable_auto_backup': 'Enable auto-backup',
  'settings_enable_auto_backup_desc':
      'Create versioned snapshots automatically when due.',
  'settings_auto_backup_interval': 'Auto-backup interval',
  'settings_auto_backup_every_6h': 'Every 6h',
  'settings_auto_backup_every_12h': 'Every 12h',
  'settings_auto_backup_every_24h': 'Every 24h',
  'settings_auto_backup_every_72h': 'Every 72h',
  'settings_last_auto_backup_never': 'Last auto-backup: never',
  'settings_last_auto_backup_at': 'Last auto-backup: {date}',
  'settings_snapshot_create_loading': 'Creating snapshot…',
  'settings_manual_snapshot_label': 'Manual snapshot',
  'settings_snapshot_created_message': 'Snapshot created: {id}',
  'settings_backup_now': 'Backup now',
  'settings_run_auto_backup_now': 'Run auto-backup now',
  'settings_auto_backup_check_loading': 'Auto-backup check…',
  'settings_snapshots_title': 'Snapshots',
  'settings_snapshots_refresh': 'Refresh snapshots',
  'settings_snapshots_delete_all': 'Delete all snapshots',
  'settings_snapshots_delete_all_title': 'Delete all snapshots',
  'settings_snapshots_delete_all_confirm':
      'Permanently delete {count} snapshot(s)? This action cannot be undone.',
  'settings_snapshots_delete_all_loading': 'Deleting all snapshots…',
  'settings_snapshots_delete_all_done': '{count} snapshot(s) deleted.',
  'settings_snapshots_delete_select_tooltip': 'Delete a selected snapshot',
  'settings_snapshots_delete_select_title': 'Delete a snapshot',
  'settings_snapshots_delete_select_desc':
      'Select the snapshot to remove (oldest first).',
  'settings_snapshots_delete_one_confirm':
      'Permanently delete "{label}"? This action cannot be undone.',
  'settings_snapshots_refresh_loading': 'Refreshing snapshots…',
  'settings_snapshots_empty': 'No snapshots found yet.',
  'settings_snapshot_list_entry': '{date} • {count} files • {size}',
  'settings_diagnostics_section_title': 'Diagnostics',
  'settings_diagnostics_page_title': 'Application Logs',
  'settings_diagnostics_page_scope_note':
      'Shows app diagnostics logs only (bot logs are excluded).',
  'settings_diagnostics_refresh': 'Refresh logs',
  'settings_diagnostics_copy_all': 'Copy all logs',
  'settings_diagnostics_empty': 'No application logs yet.',
  'settings_view_startup_logs': 'View startup logs',
  'settings_clear_logs': 'Clear logs',
  'settings_logs_cleared': 'Diagnostics log cleared',
  'settings_legal_title': 'Legal',
  'settings_legal_desc': 'Review how your data is handled and stored.',
  'settings_privacy_policy': 'Privacy Policy',
  'settings_compatibility_title': 'BDFD compatibility snapshot',
  'settings_compatibility_desc':
      'A quick view of feature coverage for users moving from BDFD.',
  'settings_compatibility_status_supported': 'Supported',
  'settings_compatibility_status_partial': 'Partial',
  'settings_compatibility_status_missing': 'Missing',
  'settings_compatibility_item_workflows_title': 'Workflow builder',
  'settings_compatibility_item_workflows_desc':
      'Visual command and response workflows are available.',
  'settings_compatibility_item_variables_title':
      'Runtime variables and templates',
  'settings_compatibility_item_variables_desc':
      'Dynamic variables and template helpers are supported.',
  'settings_compatibility_item_events_title': 'Event coverage',
  'settings_compatibility_item_events_desc':
      'Most common events are supported, some are runtime-limited.',
  'settings_compatibility_item_runner_title': 'Runner architecture',
  'settings_compatibility_item_runner_desc':
      'Remote runner is available, multi-runner support is in progress.',
  'settings_compatibility_item_bdscript_title': 'BDScript function parity',
  'settings_compatibility_item_bdscript_desc':
      'Full coverage of the BDFD function catalog.',
  'settings_compatibility_note':
      'This snapshot is intentionally high-level and will evolve with releases.',
  'settings_compatibility_open_functions': 'View compatible functions',
  'settings_compatibility_functions_title': 'Compatible BDFD Functions',
  'settings_compatibility_functions_subtitle':
      'Functions currently implemented and usable in Bot Creator BDFD mode.',
  'settings_compatibility_functions_matrix_subtitle':
      'Diff view between Bot Creator implementation and BDFD reference functions.',
  'settings_compatibility_functions_count': 'Compatible functions: {count}',
  'settings_compatibility_functions_count_bot_creator':
      'Bot Creator supported: {count}',
  'settings_compatibility_functions_count_bdfd':
      'BDFD reference total: {count}',
  'settings_compatibility_functions_count_both': 'Supported on both: {count}',
  'settings_compatibility_functions_count_missing':
      'Missing in Bot Creator: {count}',
  'settings_compatibility_functions_count_bot_only':
      'Bot Creator only: {count}',
  'settings_compatibility_functions_note':
      'This page is generated from the current implementation scope and will grow over time.',
  'settings_compatibility_functions_matrix_note':
      'BDFD-only entries are functions listed in the provided BDFD catalog but not currently implemented in Bot Creator.',
  'settings_compatibility_functions_search_hint':
      'Search a function (example: \$userJoined)',
  'settings_compatibility_functions_section_both':
      'Supported on Bot Creator and BDFD',
  'settings_compatibility_functions_section_bot_only':
      'Supported on Bot Creator only',
  'settings_compatibility_functions_section_bot_only_note':
      'Loop helpers are currently Bot Creator specific.',
  'settings_compatibility_functions_section_missing':
      'Available on BDFD but missing in Bot Creator',
  'settings_compatibility_functions_empty': 'No function in this section.',
  'settings_compatibility_functions_category_guards': 'Guards and permissions',
  'settings_compatibility_functions_category_control': 'Control flow',
  'settings_compatibility_functions_category_messages': 'Messages',
  'settings_compatibility_functions_category_embeds': 'Embeds',
  'settings_compatibility_functions_category_components':
      'Components / Interactions',
  'settings_compatibility_functions_category_logging': 'Logging',
  'settings_compatibility_functions_category_json': 'JSON helpers',
  'settings_compatibility_functions_category_http': 'HTTP helpers',
  'settings_compatibility_functions_category_variables': 'Scoped variables',
  'settings_compatibility_functions_category_threads': 'Threads',
  'settings_compatibility_functions_category_runtime': 'Runtime placeholders',
  'settings_ads_privacy_manage': 'Manage ad privacy choices',
  'settings_ads_privacy_not_required':
      'Ad privacy options are not required right now',
  'settings_ads_privacy_loading': 'Checking ad privacy settings...',
  'settings_ads_privacy_opened': 'Ad privacy options opened',
  'settings_ads_privacy_open_error': 'Could not open ad privacy options',

  // Action names
  'action_name_deleteMessages': 'Delete Messages',
  'action_name_createChannel': 'Create Channel',
  'action_name_updateChannel': 'Update Channel',
  'action_name_removeChannel': 'Remove Channel',
  'action_name_sendMessage': 'Send Message',
  'action_name_editMessage': 'Edit Message',
  'action_name_addReaction': 'Add Reaction',
  'action_name_removeReaction': 'Remove Reaction',
  'action_name_clearAllReactions': 'Clear All Reactions',
  'action_name_banUser': 'Ban User',
  'action_name_unbanUser': 'Unban User',
  'action_name_kickUser': 'Kick User',
  'action_name_muteUser': 'Mute User',
  'action_name_unmuteUser': 'Unmute User',
  'action_name_addRole': 'Add Role',
  'action_name_removeRole': 'Remove Role',
  'action_name_pinMessage': 'Pin Message',
  'action_name_updateAutoMod': 'Update AutoMod',
  'action_name_updateGuild': 'Update Guild',
  'action_name_listMembers': 'List Members',
  'action_name_getMember': 'Get Member',
  'action_name_sendComponentV2': 'Send Component V2',
  'action_name_editComponentV2': 'Edit Component V2',
  'action_name_sendWebhook': 'Send Webhook',
  'action_name_editWebhook': 'Edit Webhook',
  'action_name_deleteWebhook': 'Delete Webhook',
  'action_name_listWebhooks': 'List Webhooks',
  'action_name_getWebhook': 'Get Webhook',
  'action_name_httpRequest': 'HTTP Request',
  'action_name_setGlobalVariable': 'Set Global Variable',
  'action_name_getGlobalVariable': 'Get Global Variable',
  'action_name_removeGlobalVariable': 'Remove Global Variable',
  'action_name_setScopedVariable': 'Set Scoped Variable',
  'action_name_getScopedVariable': 'Get Scoped Variable',
  'action_name_removeScopedVariable': 'Remove Scoped Variable',
  'action_name_renameScopedVariable': 'Rename Scoped Variable',
  'action_name_listScopedVariableIndex': 'List Scoped Variable Index',
  'action_name_appendArrayElement': 'Append Array Element',
  'action_name_removeArrayElement': 'Remove Array Element',
  'action_name_queryArray': 'Query Array',

  'action_name_runWorkflow': 'Run Workflow',
  'action_name_runBdfdScript': 'Run BDFD Script',
  'action_name_respondWithMessage': 'Respond with Message',
  'action_name_respondWithComponentV2': 'Respond with Component V2',
  'action_name_respondWithModal': 'Respond with Modal',
  'action_name_editInteractionMessage': 'Edit Interaction Message',
  'action_name_listenForButtonClick': 'Listen for Button Click',
  'action_name_listenForSelectMenu': 'Listen for Select Menu',
  'action_name_listenForModalSubmit': 'Listen for Modal Submit',
  'action_name_respondWithAutocomplete': 'Respond with Autocomplete',
  'action_name_stopUnless': 'Stop Unless Condition',
  'action_name_ifBlock': 'IF / ELSE Block',
  'action_name_calculate': 'Calculate',
  'action_name_getMessage': 'Get Message',
  'action_name_unpinMessage': 'Unpin Message',
  'action_name_createPoll': 'Create Poll',
  'action_name_endPoll': 'End Poll',
  'action_name_createInvite': 'Create Invite',
  'action_name_deleteInvite': 'Delete Invite',
  'action_name_getInvite': 'Get Invite',
  'action_name_moveToVoiceChannel': 'Move to Voice Channel',
  'action_name_disconnectFromVoice': 'Disconnect from Voice',
  'action_name_serverMuteMember': 'Server Mute Member',
  'action_name_serverDeafenMember': 'Server Deafen Member',
  'action_name_createEmoji': 'Create Emoji',
  'action_name_updateEmoji': 'Update Emoji',
  'action_name_deleteEmoji': 'Delete Emoji',
  'action_name_createAutoModRule': 'Create AutoMod Rule',
  'action_name_deleteAutoModRule': 'Delete AutoMod Rule',
  'action_name_listAutoModRules': 'List AutoMod Rules',
  'action_name_getGuildOnboarding': 'Get Guild Onboarding',
  'action_name_updateGuildOnboarding': 'Update Guild Onboarding',
  'action_name_updateSelfUser': 'Update Self User (Bot Profile)',
  'action_name_createThread': 'Create Thread',
  'action_name_editChannelPermissions': 'Edit Channel Permissions',
  'action_name_deleteChannelPermission': 'Delete Channel Permission',

  'home_token_missing': 'Token not found for {botName}',
  'home_log_start_requested': 'Bot start requested',
  'home_log_stop_requested': 'Bot stop requested',
  'home_notification_permission_required':
      'Notification permission is required to start the bot.',
  'home_foreground_service_not_started':
      'The foreground service did not start.',
  'home_log_desktop_stop_requested': 'Desktop bot stop requested',
  'home_unknown_app': 'Unknown',
  'home_status_online': 'Online',
  'home_status_offline': 'Offline',
  'home_server_count_one': '{count} server',
  'home_server_count_other': '{count} servers',
  'home_stop': 'Stop',
  'home_start': 'Start',
  'home_manage': 'Manage',
  'home_logs_tooltip': 'Bot logs',
  'rewarded_start_title': 'Support Bot Creator',
  'rewarded_start_message':
      'This ad helps fund the app and can only appear when you press Start. If no ad can be shown, the bot will still start normally.',
  'rewarded_start_watch': 'Watch ad',
  'rewarded_start_continue': 'Continue',
  'rewarded_start_skip': 'Skip',
  'rewarded_start_thanks': 'Thanks for your support!',
  'ads_consent_title': 'Ads consent',
  'ads_consent_message':
      'To comply with GDPR, we need your consent before showing ads. You can continue using the app even if you refuse.',
  'ads_consent_accept': 'I accept',
  'ads_consent_refuse': 'I refuse',
  'ads_consent_refused_info':
      'Ad consent declined. The bot will still start normally.',

  'error': 'Error',
  'error_with_details': 'Error: {error}',
  'ok': 'OK',
  'close': 'Close',
  'copy': 'Copy',
  'delete': 'Delete',
  'cancel': 'Cancel',

  // Bot internal pages — app/home.dart
  'bot_home_start': 'Start Bot',
  'bot_home_starting': 'Starting…',
  'bot_home_stop': 'Stop Bot',
  'bot_home_ios_notice_title': 'Local iOS constraint',
  'bot_home_ios_notice_content':
      'In local mode, iOS may suspend the app in the background. The bot can start, but keeping the Discord connection alive is not guaranteed like it is with a Runner.',
  'bot_home_view_logs': 'View bot logs',
  'bot_home_view_stats': 'View bot stats',
  'bot_home_view_replay': 'View debugger replays',
  'bot_home_sync': 'Sync App',
  'bot_home_sync_success': 'App synced successfully',
  'bot_home_invite': 'Invite Bot',
  'bot_home_invite_error': 'Could not open invite link',
  'bot_home_delete': 'Delete App',
  'bot_home_delete_confirm': 'Are you sure you want to delete this app?',
  'bot_home_start_error': 'Could not start: {error}',
  'bot_home_log_start': 'Bot start requested',
  'bot_home_log_stop': 'Bot stop requested',
  'bot_home_log_desktop_stop': 'Desktop bot stop requested',
  'bot_home_notif_required':
      'Notification permission is required to start the bot service.',
  'bot_home_service_not_started': 'Foreground service did not start.',
  'bot_home_token_invalid_title': 'Token seems invalid',
  'bot_home_token_invalid_content':
      'Unable to connect to Discord with the provided token. It may be invalid or revoked. Do you want to start the bot anyway?',
  'bot_offline_token_desc':
      'Token invalid or missing. Enter a new Discord bot token to restore the connection.',
  'cmd_offline_incomplete_warning':
      'This command could not be fully loaded (offline or token invalid). Connect a valid token to edit.',
  'bot_settings_token_mismatch_title': 'Different bot detected',
  'bot_settings_token_mismatch_content':
      'This token belongs to bot {newId}, but the current data is for bot {oldId}. Commands and settings may not match. Continue anyway?',
  'bot_settings_token_mismatch_confirm': 'Replace token anyway',

  // Bot internal pages — app/settings.dart
  'bot_settings_title': 'Application Settings',
  'bot_settings_workflow_docs': 'Documentation Center',
  'bot_settings_workflow_docs_desc':
      'Centralized documentation for commands, workflows, runtime variables, and execution behavior.',
  'bot_settings_app_flags': 'Application Flags',
  'bot_settings_gateway_intents': 'Gateway Intents Configuration',
  'bot_settings_gateway_intents_desc':
      'Select which intents your bot needs. Configure these in the Discord Developer Portal.',
  'bot_settings_token_title': 'Bot Token',
  'bot_settings_update_token': 'Update Bot Token',
  'bot_settings_token_hint': 'Enter your bot token here',
  'bot_settings_save_success': 'Settings saved successfully',
  'bot_settings_save_token_btn': 'Save token and intents',
  'bot_settings_save_token_only_btn': 'Save token',
  'bot_settings_save_intents_btn': 'Save intents',
  'bot_settings_save_profile_status_btn': 'Save profile and statuses',
  'bot_settings_save_token_caption':
      'Token changes are protected. Click "Edit token" first, then save.',
  'bot_settings_save_intents_caption':
      'This only updates gateway intents configuration.',
  'bot_settings_save_profile_caption':
      'This applies username/avatar instantly and saves status rotation.',
  'bot_settings_token_saved': 'Token saved successfully',
  'bot_settings_intents_saved': 'Intents saved successfully',
  'bot_settings_profile_saved': 'Profile/statuses applied successfully',
  'bot_settings_edit_token_btn': 'Edit token',
  'bot_settings_cancel_token_edit_btn': 'Cancel token edit',
  'bot_settings_token_hidden_desc':
      'Token input is hidden by default for safety.',
  'bot_settings_token_required': 'Bot token is required.',
  'bot_settings_save_token_first':
      'Please save the token first before applying profile/status changes.',
  'bot_settings_profile_title': 'Bot Profile',
  'bot_settings_username_override': 'Username override',
  'bot_settings_username_hint': 'Leave empty to keep current username',
  'bot_settings_avatar_local_path': 'Avatar local file path',
  'bot_settings_avatar_path_hint': '/absolute/path/to/avatar.png',
  'bot_settings_browse': 'Browse',
  'bot_settings_avatar_selected_file': 'Selected file: {path}',
  'bot_settings_avatar_preview_label': 'Avatar preview',
  'bot_settings_avatar_preview_error': 'Unable to preview image',
  'bot_settings_avatar_unsupported_format':
      'Unsupported avatar format: {ext}. Supported formats: {formats}.',
  'bot_settings_avatar_clear_selection': 'Clear selection',
  'bot_settings_presence_status_title': 'Bot Presence Status',
  'bot_settings_presence_status_label': 'Presence',
  'bot_settings_presence_online': 'Online',
  'bot_settings_presence_idle': 'Idle (Away)',
  'bot_settings_presence_dnd': 'Do Not Disturb',
  'bot_settings_presence_invisible': 'Invisible',
  'bot_settings_status_rotation_title': 'Activities Rotation',
  'bot_settings_status_rotation_desc':
      'Add one or more activities. Each activity needs a type, name, and min/max interval (seconds).',
  'bot_settings_add_status': 'Add activity',
  'bot_settings_status_item_title': 'Activity {index}',
  'bot_settings_remove_status': 'Remove activity',
  'bot_settings_status_type_label': 'Type',
  'bot_settings_status_type_playing': 'Playing',
  'bot_settings_status_type_streaming': 'Streaming',
  'bot_settings_status_type_listening': 'Listening',
  'bot_settings_status_type_watching': 'Watching',
  'bot_settings_status_type_competing': 'Competing',
  'bot_settings_status_text_label': 'Activity name',
  'bot_settings_activity_state_label': 'Activity state (optional)',
  'bot_settings_activity_url_label': 'Stream URL (for streaming)',
  'bot_settings_status_min_interval': 'Min interval (s)',
  'bot_settings_status_max_interval': 'Max interval (s)',

  // Bot logs page
  'bot_logs_title': 'Bot Logs',
  'bot_logs_disable_debug': 'Disable debug logs',
  'bot_logs_enable_debug': 'Enable debug logs',
  'bot_logs_copied': 'Logs copied',
  'bot_logs_oldest_first': 'Show oldest first',
  'bot_logs_newest_first': 'Show newest first',
  'bot_logs_filter_count': 'Number of displayed logs',
  'bot_logs_show_n': 'Show {count} logs',
  'bot_logs_show_all': 'Show all',
  'bot_logs_empty': 'No logs yet',
  'bot_logs_show_more': 'Show more',
  'bot_logs_show_less': 'Show less',
  'bot_logs_ram': 'Bot process RAM: {memory}',
  'bot_logs_ram_estimated': 'Estimated bot RAM: {memory}',
  'bot_logs_go_to_latest': 'Go to latest log',
  'bot_logs_go_to_bottom': 'Go to bottom',

  // Debug Replay page
  'debug_replay_title': 'Debugger Replay',
  'debug_replay_start_capture': 'Enable capture',
  'debug_replay_stop_capture': 'Disable capture',
  'debug_replay_clear': 'Clear replays',
  'debug_replay_clear_title': 'Clear replays',
  'debug_replay_clear_confirm':
      'All recorded replays will be deleted. Continue?',
  'debug_replay_empty_capturing':
      'Capturing… Run a command to record a replay.',
  'debug_replay_empty_idle':
      'Capture is off. Enable it and run a command to record a replay.',
  'debug_replay_premium_title': 'Visual Debugger Replay',
  'debug_replay_premium_desc':
      'Record and replay your command executions step by step. See exactly what each action did, how long it took, and where errors occurred.',
  'debug_replay_overview': 'Overview',
  'debug_replay_play': 'Play',
  'debug_replay_pause': 'Pause',
  'debug_replay_step_first': 'First step',
  'debug_replay_step_last': 'Last step',
  'debug_replay_step_back': 'Previous step',
  'debug_replay_step_forward': 'Next step',
  'debug_replay_duration_label': 'DURATION',
  'debug_replay_result_label': 'RESULT',
  'debug_replay_result_empty': '(no result)',
  'debug_replay_start_offset': '+{ms} ms from start',
  'debug_replay_loop_info': 'Loop depth {depth}, iteration {iteration}',

  // Bot stats page
  'bot_stats_title': 'Bot Stats',
  'bot_stats_ram_process': 'Bot process RAM',
  'bot_stats_ram_estimated': 'Bot RAM only (estimated)',
  'bot_stats_cpu': 'Bot process CPU',
  'bot_stats_storage': 'Bot storage (app data)',
  'bot_stats_source_runner_api': 'Source: Runner API',
  'bot_stats_source_local_hosting': 'Source: Local Hosting',
  'bot_stats_notes':
      'Notes: CPU available on Android/Linux. Storage = bot data files in the app.',
  'bot_stats_collecting': 'Collecting…',

  // Commands list page
  'commands_title': 'Commands',
  'commands_empty': 'No commands found',
  'commands_error': 'Error: {error}',
  'commands_create_button': 'Create command',

  // Global variables page
  'globals_title': 'Global Variables',
  'globals_empty': 'No global variables yet',
  'globals_add': 'Add Variable',
  'globals_edit': 'Edit Variable',
  'globals_key': 'Key',
  'globals_value': 'Value',

  // Workflows page
  'workflows_title': 'Workflows',
  'workflows_empty': 'No workflows yet',
  'workflows_create': 'Create Workflow',
  'workflows_edit': 'Edit Workflow',
  'workflows_name': 'Workflow Name',
  'workflows_entry_point': 'Default Entry Point',
  'workflows_entry_point_hint': 'Used if caller does not override it',
  'workflows_arguments': 'Arguments',
  'workflows_arg_name': 'Name',
  'workflows_arg_default': 'Default value',
  'workflows_arg_required_short': 'Req',
  'workflows_arg_hint':
      'Arguments become runtime variables as ((arg.name)) and ((workflow.arg.name)).',
  'workflows_continue': 'Continue',
  'workflows_add_arg': 'Add argument',
  'workflows_docs_tooltip': 'Open documentation center',
  'workflows_subtitle': '{count} action(s) • entry: {entry} • args: {args}',
  'workflows_event_subtitle': '{count} action(s) • Listen for: {event}',
  'workflows_general_section': 'General Workflows',
  'workflows_event_section': 'Event Workflows',
  'workflows_type_title': 'Workflow type',
  'workflows_type_general': 'General workflow',
  'workflows_type_general_desc':
      'Reusable logic called from commands, buttons, modals, or other workflows.',
  'workflows_type_event': 'Event workflow',
  'workflows_type_event_desc':
      'Automatically reacts when Discord emits an event.',
  'workflows_type_badge_general': 'General',
  'workflows_type_badge_event': 'Event',
  'workflows_listen_for': 'Listen for',
  'workflows_event_category': 'Event category',
  'workflows_event_hint':
      'Choose the Discord event that should trigger this workflow.',
  'workflows_event_preview': 'Listen for: {event}',
  'workflows_event_available_vars': 'Available variables',
  'workflows_event_category_messages': 'Messages',
  'workflows_event_category_members': 'Members',
  'workflows_event_category_channels': 'Channels',
  'workflows_event_category_invites': 'Invites',
  'workflows_event_message_create': 'Message Create',
  'workflows_event_message_create_desc':
      'Triggered whenever a new message is created.',
  'workflows_event_message_update': 'Message Update',
  'workflows_event_message_update_desc':
      'Triggered whenever an existing message is edited.',
  'workflows_event_message_delete': 'Message Delete',
  'workflows_event_message_delete_desc':
      'Triggered whenever a message is deleted.',
  'workflows_event_member_join': 'Member Join',
  'workflows_event_member_join_desc':
      'Triggered whenever a member joins the guild.',
  'workflows_event_member_remove': 'Member Remove',
  'workflows_event_member_remove_desc':
      'Triggered whenever a member leaves or is removed from the guild.',
  'workflows_event_channel_update': 'Channel Update',
  'workflows_event_channel_update_desc':
      'Triggered whenever a channel is updated.',
  'workflows_event_invite_create': 'Invite Create',
  'workflows_event_invite_create_desc':
      'Triggered whenever an invite is created.',
  'workflows_import_tooltip': 'Import workflows',
  'workflows_export_tooltip': 'Copy workflows',
  'workflows_copy_none': 'No workflows to copy.',
  'workflows_copy_done_json': 'Workflows copied as JSON.',
  'workflows_copy_done_base64': 'Workflows copied as Base64.',
  'workflows_delete_title': 'Delete workflow',
  'workflows_delete_confirm':
      'Are you sure you want to delete "{name}"? This action cannot be undone.',
  'workflows_export_json': 'Copy as JSON',
  'workflows_export_json_desc': 'Readable and easy to edit.',
  'workflows_export_base64': 'Copy as Base64',
  'workflows_export_base64_desc': 'Convenient for compact sharing.',
  'workflows_import_title': 'Import workflows',
  'workflows_import_desc':
      'Paste a JSON payload or Base64(JSON) exported from Bot Creator.',
  'workflows_import_input_hint': 'Paste the JSON or Base64 here...',
  'workflows_import_overwrite': 'Replace when the name already exists',
  'workflows_import_action': 'Import',
  'workflows_import_empty': 'No data to import.',
  'workflows_import_invalid_format':
      'Invalid format. Use JSON or Base64(JSON).',
  'workflows_import_no_valid': 'No valid workflow found.',
  'workflows_import_done': '{count} workflow(s) imported.',

  // Command create page
  'cmd_error_fill_fields': 'Please fill all fields',
  'cmd_variables_title': 'Command Variables',
  'cmd_show_variables': 'Open variable documentation',
  'cmd_create_tooltip': 'Create command',
  'cmd_delete_tooltip': 'Delete command',
  'cmd_editor_mode_title': 'Editing mode',
  'cmd_editor_mode_simple': 'Simplified mode',
  'cmd_editor_mode_advanced': 'Advanced mode',
  'cmd_editor_mode_simple_desc':
      'Build a command quickly with guided options and preconfigured actions.',
  'cmd_editor_mode_advanced_desc':
      'Full editor with custom response, options, and action builder.',
  'cmd_editor_mode_switch_adv': 'Switch to advanced mode',
  'cmd_editor_mode_switch_adv_title': 'Switch to advanced mode?',
  'cmd_editor_mode_switch_adv_content':
      'This switch is one-way for this command. You won’t be able to return to simplified mode.',
  'cmd_editor_mode_switch_adv_confirm': 'Switch',
  'cmd_editor_mode_locked': 'Advanced mode is locked for this command.',
  'cmd_execution_mode_title': 'Execution mode',
  'cmd_execution_mode_desc':
      'Command metadata stays in the visual builder. Choose how the command body should run.',
  'cmd_execution_mode_workflow': 'Workflow mode',
  'cmd_execution_mode_workflow_desc':
      'Use the existing visual response and action builder.',
  'cmd_execution_mode_workflow_note':
      'Workflow mode is the current production path and remains fully supported.',
  'cmd_execution_mode_bdfd': 'BDFD Script mode',
  'cmd_execution_mode_bdfd_desc':
      'Write the command body as BDFD-style script while keeping command definition visual.',
  'cmd_execution_mode_bdfd_note':
      'The script is compiled to internal actions. Diagnostics are shown while editing; invalid scripts fail when the command runs.',
  'cmd_bdfd_script_label': 'BDFD script body',
  'cmd_bdfd_script_hint':
      r'$nomention\n$if[$hasPerms[$authorID;administrator]==true]\nHello from Bot Creator',
  'cmd_bdfd_diagnostics_title': 'BDFD diagnostics',
  'cmd_bdfd_diagnostics_clean': 'No issue detected in the current script.',
  'cmd_bdfd_diagnostics_error': 'Error',
  'cmd_bdfd_diagnostics_warning': 'Warning',
  'cmd_bdfd_script_empty_error': 'BDFD script body cannot be empty.',
  'cmd_bdfd_script_validation_error':
      'This BDFD script still contains diagnostics:',
  'cmd_bdfd_autocomplete_title': 'BDFD prefix autocomplete',
  'cmd_bdfd_autocomplete_hint':
      'Type \$ and start writing a function name to get quick script suggestions.',
  'workflow_mode_title': 'Workflow mode',
  'workflow_mode_desc':
      'Choose between a visual action builder or a full BDFD scripting editor.',
  'workflow_mode_visual': 'Visual',
  'workflow_mode_bdfd': 'BDFD Script',
  'workflow_mode_visual_note':
      'Build your workflow visually by adding individual actions with the card editor.',
  'workflow_mode_bdfd_note':
      'Write your entire workflow as a single BDFD script. The script is compiled and validated in real time.',
  'workflow_bdfd_editor_title': 'BDFD Script Editor',
  'workflow_bdfd_editor_desc':
      'Write the complete BDFD code for this workflow response. Diagnostics are displayed live.',
  'bdfd_editor_title': 'BDFD Editor',
  'bdfd_editor_tap_hint': 'Tap to open editor',
  'bdfd_editor_wrap_toggle': 'Toggle line wrapping',
  'bdfd_editor_diagnostics_toggle': 'Toggle diagnostics panel',
  'bdfd_editor_empty': 'Empty script — start typing to see diagnostics.',
  'bdfd_editor_docs': 'BDFD Functions Reference',
  'bdfd_docs_title': 'BDFD Docs',
  'bdfd_docs_search_hint': 'Search functions…',
  'bdfd_docs_empty': 'No matching functions.',
  'bdfd_docs_syntax': 'SYNTAX',
  'bdfd_docs_parameters': 'PARAMETERS',
  'bdfd_docs_no_params': 'No parameters — use as \$functionName',
  'bdfd_docs_category_messages': 'Messages & Content',
  'bdfd_docs_category_embeds': 'Embeds',
  'bdfd_docs_category_components': 'Components',
  'bdfd_docs_category_modals': 'Modals',
  'bdfd_docs_category_control': 'Control Flow',
  'bdfd_docs_category_guards': 'Guards & Permissions',
  'bdfd_docs_category_moderation': 'Moderation',
  'bdfd_docs_category_variables': 'Variables',
  'bdfd_docs_category_json': 'JSON',
  'bdfd_docs_category_http': 'HTTP Requests',
  'bdfd_docs_category_math': 'Math',
  'bdfd_docs_category_text': 'Text & Strings',
  'bdfd_docs_category_channels': 'Channels & Threads',
  'bdfd_docs_category_roles': 'Roles',
  'bdfd_docs_category_reactions': 'Reactions',
  'bdfd_docs_category_cooldowns': 'Cooldowns',
  'bdfd_docs_category_webhooks': 'Webhooks',
  'bdfd_docs_category_leaderboards': 'Leaderboards',
  'bdfd_docs_category_tickets': 'Tickets',
  'bdfd_docs_category_misc': 'Other',
  'bdfd_docs_desc_for':
      'Bot Creator only — Repeats a block of code N times.\n\nSimple: \$for[5]...\$endfor → the body is repeated 5 times (max 100). You can use \$i for the current index (starting at 0) and \$loopCount for the total.\n\nC-style: \$for[i=0;i<10;i++]...\$endfor → classic for loop with init, condition and update. Supports ++, --, +=, -=, *=.\n\nIf the iteration count is dynamic (e.g. \$for[\$args[1]]), the loop runs at runtime instead of compile-time.',
  'bdfd_docs_desc_loop':
      'Bot Creator only — Alias for \$for. See \$for for details. Use \$endloop to close the block.',
  'bdfd_docs_desc_callworkflow':
      'Bot Creator only — Calls another workflow by name and passes arguments.\n\nSyntax: \$callWorkflow[myWorkflow;key1=value1;key2=value2]\n\nThe called workflow can read arguments and return a value via \$workflowResponse.',
  'bdfd_docs_desc_workflowresponse':
      'Bot Creator only — Returns the response from the last \$callWorkflow.\n\nUse \$workflowResponse[] for the full response, or \$workflowResponse[property] to access a specific field.',
  'bdfd_docs_desc_eval':
      'Executes a BDFD script string at runtime. The code passed as argument is re-compiled and executed dynamically. Useful for running user-provided or variable-based scripts.',
  'bdfd_docs_desc_if':
      'Conditional block. Supports nesting and rich operators: ==, !=, >=, <=, >, <, contains, startsWith, endsWith, notContains.\n\nUsage:\n\$if[\$authorID==123456]\n  Hello admin!\n\$elseif[\$hasRole[789]]\n  Hello member!\n\$else\n  Hello guest!\n\$endif',
  'bdfd_docs_desc_elseif':
      'Adds an alternative condition inside an \$if block. Must appear between \$if and \$else/\$endif.',
  'bdfd_docs_desc_try':
      'Wraps a block for error handling.\n\nUsage:\n\$try\n  \$httpGet[https://api.example.com/data]\n\$catch\n  Request failed!\n\$endtry\n\nIf any function in the \$try block fails, execution jumps to \$catch.',
  'bdfd_docs_desc_stop':
      'Immediately stops execution of the current script. No further actions after \$stop will run.',
  'bdfd_docs_desc_suppresserrors':
      'Prevents error messages from being sent to the user. If any action fails, the error is silently suppressed.',
  'bdfd_docs_desc_embedsuppresserrors':
      'Same as \$suppressErrors — suppresses all error messages silently.',
  'bdfd_docs_desc_and':
      'Logical AND — combines multiple conditions. All must be true.\n\nUsage: \$if[\$and[\$authorID==123;\$hasRole[456]]]',
  'bdfd_docs_desc_or':
      'Logical OR — combines multiple conditions. At least one must be true.\n\nUsage: \$if[\$or[\$authorID==123;\$authorID==456]]]',
  'bdfd_docs_desc_awaitfunc':
      'Registers a callback that waits for a user response.\n\nUsage: \$awaitFunc[name;userID (opt);channelID (opt)]\n\nThe awaited function is stored and triggered when the target user sends a message in the target channel.',
  'bdfd_docs_desc_defer':
      'Defers the interaction response, giving you more time to process. The user sees a "Bot is thinking…" message. Use before long operations like HTTP requests.',
  'bdfd_docs_desc_ephemeral':
      'Makes the response visible only to the user who triggered the command. Must be placed before any response content.',
  'bdfd_docs_desc_jsonparse':
      'Parses a JSON string into memory for manipulation. All JSON operations (\$jsonSet, \$json, etc.) operate on this parsed context.\n\nStatic JSON is resolved at compile-time for better performance.',
  'bdfd_docs_desc_jsonset':
      'Sets a value in the current JSON context. Supports dot-notation paths.\n\nUsage: \$jsonSet[user.name;John]\n\nThe change is applied in memory — use \$jsonStringify to get the result.',
  'bdfd_docs_desc_jsonstringify':
      'Converts the current JSON context back to a string. Use after \$jsonParse and \$jsonSet operations to output the result.',
  'bdfd_docs_desc_httpget':
      'Sends an HTTP GET request to the given URL. Use \$httpAddHeader before to set headers. Use \$httpResult to read the response.\n\nAll HTTP methods (GET, POST, PUT, PATCH, DELETE) follow the same pattern.',
  'bdfd_docs_desc_httpaddheader':
      'Adds a header to the next HTTP request. Headers are accumulated until the next \$httpGet/\$httpPost/etc.\n\nUsage: \$httpAddHeader[Authorization;Bearer token123]',
  'bdfd_docs_desc_httpresult':
      'Returns the body of the last HTTP response. Optionally pass a JSON path to extract a specific field.\n\nUsage: \$httpResult[] for the full body, or \$httpResult[data.name] for a nested field.',
  'done': 'Done',
  'cmd_simple_actions_title': 'Simplified actions',
  'cmd_simple_actions_desc':
      'Select what this command should do. Options are generated automatically.',
  'cmd_simple_group_moderation_title': 'Moderation',
  'cmd_simple_group_moderation_desc':
      'Member and moderation actions with guided options.',
  'cmd_simple_group_messages_title': 'Messages',
  'cmd_simple_group_messages_desc':
      'Message and channel actions that work in the current context.',
  'cmd_simple_group_utility_title': 'Utility',
  'cmd_simple_group_utility_desc': 'Helpful extras such as invites and polls.',
  'cmd_simple_action_delete': 'Delete messages',
  'cmd_simple_action_delete_desc':
      'Delete messages in the current channel (optional /count).',
  'cmd_simple_action_kick': 'Kick user',
  'cmd_simple_action_kick_desc': 'Kick the selected /user from the server.',
  'cmd_simple_action_ban': 'Ban user',
  'cmd_simple_action_ban_desc': 'Ban the selected /user from the server.',
  'cmd_simple_action_unban': 'Unban user',
  'cmd_simple_action_unban_desc':
      'Unban a user with a provided /user_id string.',
  'cmd_simple_action_mute': 'Mute user',
  'cmd_simple_action_mute_desc': 'Temporarily mute the selected /user.',
  'cmd_simple_action_unmute': 'Unmute user',
  'cmd_simple_action_unmute_desc':
      'Remove the timeout from the selected /user.',
  'cmd_simple_action_add_role': 'Add role',
  'cmd_simple_action_add_role_desc':
      'Give the selected /role to the selected /user.',
  'cmd_simple_action_remove_role': 'Remove role',
  'cmd_simple_action_remove_role_desc':
      'Remove the selected /role from the selected /user.',
  'cmd_simple_action_send_message': 'Send message',
  'cmd_simple_action_send_message_desc':
      'Send an additional message in the current channel.',
  'cmd_simple_action_pin': 'Pin message',
  'cmd_simple_action_pin_desc':
      'Pin a message in the current channel using /message_id.',
  'cmd_simple_action_unpin': 'Unpin message',
  'cmd_simple_action_unpin_desc':
      'Unpin a message in the current channel using /message_id.',
  'cmd_simple_action_create_invite': 'Create invite',
  'cmd_simple_action_create_invite_desc':
      'Create an invite for the current channel or an optional /channel.',
  'cmd_simple_action_create_poll': 'Create poll',
  'cmd_simple_action_create_poll_desc':
      'Create a poll with a dynamic /question and fixed answer choices.',
  'cmd_simple_action_send_message_label': 'Action message',
  'cmd_simple_action_send_message_hint':
      'Message sent by the Send Message action',
  'cmd_simple_execution_title': 'Execution settings',
  'cmd_simple_execution_desc':
      'Fine-tune the generated actions without leaving simplified mode.',
  'cmd_simple_action_reason_label': 'Audit log reason',
  'cmd_simple_action_reason_hint':
      'Optional reason shared by moderation actions',
  'cmd_simple_action_delete_default_count_label': 'Default delete count',
  'cmd_simple_action_delete_default_count_hint':
      'Used when /count is not provided',
  'cmd_simple_action_ban_delete_days_label': 'Ban delete message days',
  'cmd_simple_action_ban_delete_days_hint':
      '0 to 7 days of recent messages to delete',
  'cmd_simple_action_mute_duration_label': 'Mute duration',
  'cmd_simple_action_mute_duration_hint':
      'Examples: 10m, 2h, 1d, or raw seconds',
  'cmd_simple_generated_options': 'Generated command options',
  'cmd_simple_generated_none':
      'No options generated yet. Select at least one action.',
  'cmd_simple_option_user': '/user (User)',
  'cmd_simple_option_role': '/role (Role)',
  'cmd_simple_option_count': '/count (Integer)',
  'cmd_simple_option_user_id': '/user_id (Text)',
  'cmd_simple_option_message_id': '/message_id (Text)',
  'cmd_simple_option_channel': '/channel (Channel)',
  'cmd_simple_option_question': '/question (Text)',
  'cmd_simple_option_user_desc': 'Target user',
  'cmd_simple_option_role_desc': 'Target role',
  'cmd_simple_option_count_desc': 'Number of messages to delete',
  'cmd_simple_option_user_id_desc': 'User ID to unban',
  'cmd_simple_option_message_id_desc': 'Message ID to target',
  'cmd_simple_option_channel_desc':
      'Optional channel override for invite creation',
  'cmd_simple_option_question_desc': 'Poll question',
  'cmd_simple_invite_settings_title': 'Invite settings',
  'cmd_simple_invite_settings_desc':
      'Defaults used by the generated Create Invite action.',
  'cmd_simple_invite_max_age_label': 'Invite expiry (seconds)',
  'cmd_simple_invite_max_age_hint': '0 for no expiry, up to 604800',
  'cmd_simple_invite_max_uses_label': 'Max uses',
  'cmd_simple_invite_max_uses_hint': '0 for unlimited uses',
  'cmd_simple_invite_temporary_label': 'Temporary membership',
  'cmd_simple_invite_temporary_desc':
      'Members are removed if they leave before getting a role.',
  'cmd_simple_invite_unique_label': 'Force unique invite',
  'cmd_simple_invite_unique_desc':
      'Always create a new invite instead of reusing an existing one.',
  'cmd_simple_poll_settings_title': 'Poll settings',
  'cmd_simple_poll_settings_desc':
      'Defaults used by the generated Create Poll action.',
  'cmd_simple_poll_answers_label': 'Poll answers',
  'cmd_simple_poll_answers_hint':
      'One answer per line, or use commas. Minimum 2, maximum 10.',
  'cmd_simple_poll_duration_label': 'Poll duration (hours)',
  'cmd_simple_poll_duration_hint': 'From 1 to 168 hours',
  'cmd_simple_poll_multiselect_label': 'Allow multiple answers',
  'cmd_simple_poll_multiselect_desc': 'Users can select more than one choice.',
  'cmd_simple_response_title': 'Final response',
  'cmd_simple_response_desc':
      'Message sent back to the user after actions are executed.',
  'cmd_simple_response_visibility_label': 'Response visibility',
  'cmd_simple_response_visibility_public': 'Public',
  'cmd_simple_response_visibility_ephemeral': 'Ephemeral',
  'cmd_simple_response_hint': 'Done ✅',
  'cmd_simple_response_embeds_title': 'Response embeds',
  'cmd_simple_response_embeds_desc':
      'Optional embeds sent with the final response.',
  'cmd_simple_conflict_ban_unban':
      'Ban user and Unban user cannot be enabled together in simplified mode.',
  'cmd_simple_conflict_mute_unmute':
      'Mute user and Unmute user cannot be enabled together in simplified mode.',
  'cmd_simple_conflict_pin_unpin':
      'Pin message and Unpin message cannot be enabled together in simplified mode.',
  'cmd_simple_invite_max_age_invalid':
      'Invite expiry must be a number between 0 and 604800 seconds.',
  'cmd_simple_invite_max_uses_invalid':
      'Invite max uses must be a number between 0 and 1000000.',
  'cmd_simple_poll_answers_invalid':
      'Poll answers must contain between 2 and 10 non-empty choices.',
  'cmd_simple_poll_duration_invalid':
      'Poll duration must be a number between 1 and 168 hours.',
  'cmd_simple_send_message_required':
      'Please fill the action message before saving.',

  // Support & community
  'support_card_title': 'Support & Community',
  'support_card_desc':
      'A question, a bug, a suggestion? Come chat with the team and the community.',
  'support_join_discord': 'Join the Discord server',
  'support_discord_badge': 'Official support',
  'home_empty_support_hint': 'Need help getting started?',
  'home_empty_support_btn': 'Join our Discord',

  // Action errors
  'error_invalid_count': 'Count must be greater than 0.',
  'error_invalid_channel_type': 'Channel is not a text channel.',
  'error_network_timeout': 'The action timed out. Please try again.',
  'error_delete_messages_failed': 'Failed to delete messages.',

  // Documentation center
  'doc_center_title': 'Documentation Center',
  'doc_center_search_hint':
      'Search commands, workflows, variables, actions, intents, or examples...',
  'doc_center_clear_search': 'Clear search',
  'doc_center_empty': 'No documentation entry matches your search.',
  'doc_kind_all': 'All',
  'doc_kind_event': 'Event',
  'doc_kind_action': 'Action',
  'doc_kind_template': 'Template',
  'doc_kind_runtime': 'Runtime',
  'doc_required_intents': 'Required Intents',
  'doc_available_variables': 'Available Variables',
  'doc_example': 'Example',
  'doc_common_section_best_use_cases': 'Best Use Cases',
  'doc_common_section_important_notes': 'Important Notes',

  // Docs - Template Variables
  'doc_template_variables_title': 'Template Variables',
  'doc_template_variables_subtitle': 'How dynamic placeholders are resolved.',
  'doc_template_variables_summary':
      'Runtime resolves placeholders using current event/interaction context, workflow args, and global vars.',
  'doc_template_variables_section_sources_title': 'Variable Sources',
  'doc_template_variables_section_sources_l1':
      'Command variables: commandName, commandId, commandType, target.*, opts.*.',
  'doc_template_variables_section_sources_l2':
      'Event variables: event.*, message.*, reaction.*, voice.*, role.*, etc.',
  'doc_template_variables_section_sources_l3':
      'Workflow variables: workflow.name, workflow.entryPoint, arg.*, workflow.arg.*',
  'doc_template_variables_section_sources_l4': 'Global variables: global.<key>',
  'doc_template_variables_section_sources_l5':
      'Action outputs: action.<key> when available.',
  'doc_template_variables_section_builtin_title': 'Built-in Command Variables',
  'doc_template_variables_section_types_title': 'Command Types',
  'doc_template_variables_section_types_l1':
      'Slash commands use commandType = chatInput and expose opts.<option> variables.',
  'doc_template_variables_section_types_l2':
      'User commands use commandType = user and expose target.user.* variables.',
  'doc_template_variables_section_types_l3':
      'Message commands use commandType = message and expose target.message.* variables.',
  'doc_template_variables_section_types_l4':
      'Subcommands still expose their arguments through opts.*.',
  'doc_template_variables_section_fallbacks_title': 'Fallbacks and Paths',
  'doc_template_variables_section_fallbacks_l1':
      'Use ((opts.user|userName)) to fall back when an option is missing.',
  'doc_template_variables_section_fallbacks_l2':
      'Use JSONPath syntax on action outputs: ((myHttp.body.\$.data[0].id)); arrays and objects stay queryable.',
  'doc_template_variables_section_fallbacks_l3':
      'Functions like length(...), join(...), formatEach(...), and embedFields(...) are also supported; unknown variables still resolve to an empty string.',
  'doc_template_variables_example':
      'Hello ((target.user.username|userName))\nPlayers: ((join(scores.items.\$, ", ")))\nFields JSON: ((embedFields(scores.items.\$, "{name}", "{score}", true)))',

  // Docs - Template Functions
  'doc_template_functions_title': 'Template Functions',
  'doc_template_functions_subtitle':
      'Transform and compare data inside ((...)) expressions.',
  'doc_template_functions_summary':
      'Use template functions to normalize text, inspect arrays, build output blocks, and add lightweight randomness.',
  'doc_template_functions_section_string_title': 'String Helpers',
  'doc_template_functions_section_string_l1':
      'lowercase(source) / lower(source): convert text to lowercase.',
  'doc_template_functions_section_string_l2':
      'uppercase(source) / upper(source): convert text to uppercase.',
  'doc_template_functions_section_string_l3':
      'trim(source): remove leading and trailing spaces.',
  'doc_template_functions_section_string_l4':
      'replace(source, search, replacement) and contains(source, needle) for substitutions and checks.',
  'doc_template_functions_section_array_title': 'Array and Aggregate Helpers',
  'doc_template_functions_section_array_l1':
      'length(source), at(source, index), first(source), last(source).',
  'doc_template_functions_section_array_l2':
      'slice(source, start, end?) and join(source, separator).',
  'doc_template_functions_section_array_l3':
      'sum(source): adds numeric items and ignores non-numeric values.',
  'doc_template_functions_section_array_l4':
      'formatEach(...) and embedFields(...) format object arrays for text and embeds.',
  'doc_template_functions_section_random_title': 'Random Helpers',
  'doc_template_functions_section_random_l1':
      'coin() and random(): return "true" or "" for conditional branching.',
  'doc_template_functions_section_random_l2':
      'randomchoice(a, b, ...) and randomint(min, max).',
  'doc_template_functions_section_notes_title': 'Important Notes',
  'doc_template_functions_section_notes_l1':
      'Function names are case-insensitive.',
  'doc_template_functions_section_notes_l2':
      'Unknown functions or invalid arguments resolve to an empty string.',
  'doc_template_functions_section_notes_l3':
      'Use fallback syntax with | at root level: ((replace(name, "_", " ")|Unknown)).',
  'doc_template_functions_section_notes_l4':
      'Arrays and objects returned by functions are serialized as JSON text.',
  'doc_template_functions_example':
      'Normalized: ((uppercase(trim(userName))))\nHas admin role: ((contains(userRole, "admin")))\nTop score: ((first(scores.\$)))\nTotal score: ((sum(scores.\$)))',

  // Docs - Template Advanced Variables
  'doc_template_advanced_variables_title': 'Template Advanced Variables',
  'doc_template_advanced_variables_subtitle':
      'Additional runtime keys available in specific contexts.',
  'doc_template_advanced_variables_summary':
      'These keys are generated from interaction payloads and channel/guild/user runtime details, depending on the event or command type.',
  'doc_template_advanced_variables_section_interaction_title':
      'Interaction Metadata',
  'doc_template_advanced_variables_section_interaction_l1':
      'interaction.kind identifies the incoming interaction mode (button, select, modal, command, autocomplete).',
  'doc_template_advanced_variables_section_interaction_l2':
      'interaction.values and interaction.values.count are populated for select menus.',
  'doc_template_advanced_variables_section_interaction_l3':
      'interaction.command.name and interaction.command.id are useful for diagnostics and routing checks.',
  'doc_template_advanced_variables_section_channel_guild_title':
      'Channel and Guild Details',
  'doc_template_advanced_variables_section_channel_guild_l1':
      'channel.kind, channel.position, channel.bitrate, and channel.userLimit are context-dependent channel details.',
  'doc_template_advanced_variables_section_channel_guild_l2':
      'Thread contexts can expose channel.thread.* values (archived, locked, ownerId, autoArchiveDuration).',
  'doc_template_advanced_variables_section_channel_guild_l3':
      'guild.kind helps distinguish partial/full guild payloads in advanced workflows.',
  'doc_template_advanced_variables_section_aliases_title':
      'User and Member Aliases',
  'doc_template_advanced_variables_section_aliases_l1':
      'Structured user aliases (user.id, user.username, user.tag, user.avatar, user.banner) are available in many command contexts.',
  'doc_template_advanced_variables_section_aliases_l2':
      'member.id can be useful when both user and guild-member context are needed.',
  'doc_template_advanced_variables_example':
      'Kind: ((interaction.kind))\nSelected count: ((interaction.values.count|0))\nThread owner: ((channel.thread.ownerId|unknown))\nGuild payload kind: ((guild.kind|n/a))',

  // Docs - Runtime Action Outputs
  'doc_runtime_action_outputs_title': 'Runtime Action Outputs',
  'doc_runtime_action_outputs_subtitle':
      'How action result keys are exposed as runtime variables.',
  'doc_runtime_action_outputs_summary':
      'Most actions write a primary result key and may also expose prefixed fields under action.<resultKey>.* depending on the executor.',
  'doc_runtime_action_outputs_section_patterns_title': 'Output Patterns',
  'doc_runtime_action_outputs_section_patterns_l1':
      'Primary output is usually stored as <resultKey>.',
  'doc_runtime_action_outputs_section_patterns_l2':
      'Many executors also expose action.<resultKey>.* fields for clarity and namespacing.',
  'doc_runtime_action_outputs_section_patterns_l3':
      'Some fields are mirrored with and without the action. prefix.',
  'doc_runtime_action_outputs_section_common_fields_title':
      'Common Output Fields',
  'doc_runtime_action_outputs_section_common_fields_l1':
      'HTTP actions: status, body, jsonPath.',
  'doc_runtime_action_outputs_section_common_fields_l2':
      'Messaging/list actions: count, mode, deleteItself, deleteResponse.',
  'doc_runtime_action_outputs_section_common_fields_l3':
      'Array actions: items, length, removed, total.',
  'doc_runtime_action_outputs_section_common_fields_l4':
      'Other executors may expose result or messageId fields.',
  'doc_runtime_action_outputs_section_caveats_title': 'Caveats',
  'doc_runtime_action_outputs_section_caveats_l1':
      'Not every action exposes every suffix; availability is executor-specific.',
  'doc_runtime_action_outputs_section_caveats_l2':
      'For portability, prefer fallback expressions when reading optional output fields.',
  'doc_runtime_action_outputs_section_caveats_l3':
      'If a key is missing, template resolution returns an empty string.',
  'doc_runtime_action_outputs_example':
      'Status: ((action.http.status|http.status|unknown))\nBody: ((action.http.body|http.body))\nDeleted: ((cleanup.count|0))\nTotal: ((page.total|0))',

  // Docs - Interaction Commands
  'doc_interaction_commands_title': 'Interaction Commands',
  'doc_interaction_commands_subtitle':
      'Slash, user and message command runtime behavior.',
  'doc_interaction_commands_summary':
      'Application commands are executed through a shared interaction path, with runtime variables depending on the Discord command type.',
  'doc_interaction_commands_section_execution_title': 'Execution Model',
  'doc_interaction_commands_section_execution_l1':
      'Slash, user and message commands all enter the runner as application command interactions.',
  'doc_interaction_commands_section_execution_l2':
      'The runner matches commands by Discord command id, then validates stored type vs incoming type.',
  'doc_interaction_commands_section_execution_l3':
      'A type mismatch is logged as warning but does not hard-stop execution.',
  'doc_interaction_commands_section_per_type_title': 'Per-Type Variables',
  'doc_interaction_commands_section_per_type_l1':
      'chatInput: opts.* for parameters and subcommands.',
  'doc_interaction_commands_section_per_type_l2':
      'user: target.user.* and target.member.* when available.',
  'doc_interaction_commands_section_per_type_l3':
      'message: target.message.* including content and author id when resolved.',
  'doc_interaction_commands_section_builtin_title':
      'Built-in Command Variables',
  'doc_interaction_commands_section_guidance_title': 'Authoring Guidance',
  'doc_interaction_commands_section_guidance_l1':
      'Write conditional logic against commandType or interaction.command.type.',
  'doc_interaction_commands_section_guidance_l2':
      'Prefer fallback syntax when sharing a template between slash and non-slash commands, and use autocomplete.query inside dedicated autocomplete workflows.',
  'doc_interaction_commands_section_guidance_l3':
      'Keep templates portable by avoiding event-only names inside command workflows; dynamic autocomplete requires a general workflow ending with respondWithAutocomplete.',
  'doc_interaction_commands_example':
      'Autocomplete workflow:\nquery = ((autocomplete.query))\nqueryArray -> items=((httpSearch.body))\nrespondWithAutocomplete -> label={name} value={id}',

  // Docs - Event: messageCreate
  'doc_event_message_create_title': 'Event: messageCreate',
  'doc_event_message_create_subtitle':
      'Triggered for each newly created message.',
  'doc_event_message_create_summary':
      'Use this event for moderation, keyword pipelines, auto-replies, command-style parsing, and analytics.',
  'doc_event_message_create_intent_1': 'Guild Messages',
  'doc_event_message_create_intent_2': 'Message Content',
  'doc_event_message_create_best_use_l1':
      'Detect commands typed without slash commands.',
  'doc_event_message_create_best_use_l2':
      'Apply anti-spam filters before answering.',
  'doc_event_message_create_best_use_l3':
      'Route to reusable workflows based on first word or mention.',
  'doc_event_message_create_notes_l1':
      'If Message Content intent is off, content-dependent conditions can fail.',
  'doc_event_message_create_notes_l2':
      'message.content[index] is word-based and capped by runtime extraction.',
  'doc_event_message_create_notes_l3': 'author.isBot can help avoid bot loops.',
  'doc_event_message_create_example':
      'Guard: ((message.isBot)) equals false\nGuard: ((message.content[0])) equals !ticket\nThen: runWorkflow -> ticket_manager entry=create',

  // Docs - Runtime execution flow
  'doc_runtime_execution_flow_title': 'Runtime Execution Flow',
  'doc_runtime_execution_flow_subtitle':
      'How event workflows are selected and executed.',
  'doc_runtime_execution_flow_summary':
      'When an event arrives, runtime matches configured workflows by eventTrigger.event then executes actions with context variables.',
  'doc_runtime_execution_flow_section_pipeline_title': 'Pipeline',
  'doc_runtime_execution_flow_section_pipeline_l1': '1) Receive gateway event.',
  'doc_runtime_execution_flow_section_pipeline_l2':
      '2) Build context variables map.',
  'doc_runtime_execution_flow_section_pipeline_l3':
      '3) Match workflows by event name.',
  'doc_runtime_execution_flow_section_pipeline_l4':
      '4) Merge global variables.',
  'doc_runtime_execution_flow_section_pipeline_l5':
      '5) Execute actions sequentially with conditions.',
  'doc_runtime_execution_flow_section_parity_title': 'Parity Rule',
  'doc_runtime_execution_flow_section_parity_l1':
      'Variables should be identical between local app runtime and runner runtime.',
  'doc_runtime_execution_flow_section_parity_l2':
      'Use same variable names in conditions to stay portable.',

  // ── Template Gallery ────────────────────────────────────────────────────
  'template_gallery_title': 'Templates',
  'template_gallery_subtitle':
      'Quick-start your bot with a ready-made template.',
  'template_gallery_apply': 'Use this template',
  'template_gallery_apply_success':
      '{count} command(s) and {wCount} workflow(s) added from template.',
  'template_gallery_apply_error': 'Failed to apply template: {error}',
  'template_gallery_commands_count': '{count} command(s)',
  'template_gallery_workflows_count': '{count} workflow(s)',
  'template_gallery_empty': 'No templates available.',
  'template_gallery_already_exists':
      'Command "{name}" already exists and was skipped.',
  'template_gallery_sync_warning':
      'Commands saved locally. Start your bot to register them on Discord.',
  'template_welcome_name': 'Welcome Bot',
  'template_welcome_description':
      'Greet new members, say hello, and show server info.',
  'template_moderation_name': 'Moderation Bot',
  'template_moderation_description':
      'Ban, kick, mute members and clear messages.',
  'template_utility_name': 'Utility Bot',
  'template_utility_description': 'Ping, avatar lookup, and bot-says commands.',
  'template_fun_name': 'Fun Bot',
  'template_fun_description': 'Coin flip, polls, and magic 8-ball.',

  // ── Command Usage Dashboard ────────────────────────────────────────────
  'dashboard_title': 'Dashboard',
  'dashboard_no_data':
      'No command usage data yet. Run your bot to start tracking.',
  'dashboard_total': 'Total commands',
  'dashboard_period_24h': 'Last 24h',
  'dashboard_period_7d': 'Last 7 days',
  'dashboard_period_30d': 'Last 30 days',
  'dashboard_top_commands': 'Top commands',
  'dashboard_top_locales': 'Top locales',
  'dashboard_execution_health_title': 'Execution health',
  'dashboard_failed_commands': 'Failed',
  'dashboard_error_rate': 'Error rate',
  'dashboard_p50_latency': 'Latency p50',
  'dashboard_p95_latency': 'Latency p95',
  'dashboard_premium_analytics_title': 'Premium analytics',
  'dashboard_premium_analytics_desc':
      'Unlock error rate, latency percentiles, and locale insights.',
  'dashboard_timeline': 'Usage over time',
  'dashboard_executions': '{count} executions',
  'dashboard_selected_period_total': '{count} in selected period',
  'dashboard_loading': 'Loading stats...',
  'dashboard_error': 'Could not load stats: {error}',
  'dashboard_refresh_sources_tooltip': 'Refresh execution servers',
  'dashboard_requires_runner':
      'Connect to a runner to see command usage stats.',
  'dashboard_single_runner_notice':
      'Stats shown are from the currently configured runner only. If you run bots on multiple runners, this view may be incomplete.',
  'runner_source_label': 'Runner: {name}',
  'runner_source_local': 'Local',
  'runner_source_all': 'All runners',
  'runner_select_source': 'Select runner',
  'logs_runner_source': 'Logs from: {name}',

  // ── Version info ──
  'settings_version_title': 'Version',
  'settings_app_version': 'App',
  'settings_runner_version': 'Runner',
  'settings_runner_not_connected': 'Not connected',

  // ── Premium / Subscription ──
  'premium_card_title': 'Remove Ads',
  'premium_card_desc':
      'Subscribe to remove all ads and start your bots instantly, without any popup.',
  'premium_card_button': 'See plans',
  'premium_active_title': 'Premium active',
  'premium_active_desc': 'Thank you for your support! All ads are disabled.',
  'subscription_title': 'Remove Ads',
  'subscription_subtitle':
      'Choose a plan to remove ads and unlock all premium features.',
  'subscription_benefit_no_ads': 'No ads anywhere in the app',
  'subscription_benefit_fast_start': 'Bots start instantly, no popup',
  'subscription_benefit_support': 'Support independent development',
  'subscription_feature_coming_soon': 'Coming soon',
  'subscription_feature_no_ads_title': 'No ads',
  'subscription_feature_no_ads_desc':
      'Remove all ad placements across the app experience.',
  'subscription_feature_instant_start_title': 'Instant start',
  'subscription_feature_instant_start_desc':
      'Start bots immediately without rewarded ad interruption.',
  'subscription_feature_analytics_title': 'Advanced analytics',
  'subscription_feature_analytics_desc':
      'Access error rate, latency percentiles, and locale insights.',
  'subscription_feature_scheduler_title': 'Scheduler triggers',
  'subscription_feature_scheduler_desc':
      'Run workflows automatically every X minutes (up to 10 active).',
  'subscription_feature_webhooks_title': 'Inbound webhooks',
  'subscription_feature_webhooks_desc':
      'Create secure webhook endpoints and route calls to workflows.',
  'subscription_feature_debug_replay_title': 'Visual debug replay',
  'subscription_feature_debug_replay_desc':
      'Record and replay command actions step by step for debugging.',
  'subscription_feature_auto_sharding_title': 'Automatic sharding',
  'subscription_feature_auto_sharding_desc':
      'Scale large bots by distributing load across shard workers.',
  'subscription_feature_auto_restart_title': 'Automatic restart',
  'subscription_feature_auto_restart_desc':
      'Restart the bot automatically when a full restart is required.',
  'subscription_annual_title': 'Annual',
  'subscription_monthly_title': 'Monthly',
  'subscription_per_year': 'per year',
  'subscription_per_month': 'per month',
  'subscription_save_badge': 'SAVE 67%',
  'subscription_restore': 'Restore purchases',
  'subscription_terms': 'Terms of use',
  'subscription_privacy': 'Privacy policy',
  'subscription_error': 'Purchase could not be completed. Please try again.',
  'subscription_restored': 'Subscription restored successfully!',
  'subscription_restore_not_found': 'No active subscription found.',
  'subscription_not_available_on_platform':
      'Subscriptions are currently available on mobile only.',
};
