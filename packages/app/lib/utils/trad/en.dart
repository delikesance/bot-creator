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
  'settings_snapshots_refresh_loading': 'Refreshing snapshots…',
  'settings_snapshots_empty': 'No snapshots found yet.',
  'settings_snapshot_list_entry': '{date} • {count} files • {size}',
  'settings_diagnostics_section_title': 'Diagnostics',
  'settings_view_startup_logs': 'View startup logs',
  'settings_clear_logs': 'Clear logs',
  'settings_logs_cleared': 'Diagnostics log cleared',
  'settings_legal_title': 'Legal',
  'settings_legal_desc': 'Review how your data is handled and stored.',
  'settings_privacy_policy': 'Privacy Policy',
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
  'bot_home_stop': 'Stop Bot',
  'bot_home_view_logs': 'View bot logs',
  'bot_home_view_stats': 'View bot stats',
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
};
