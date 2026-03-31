import 'package:bot_creator/utils/i18n.dart';
import 'package:bot_creator_shared/utils/bdfd_signature_hints.dart';
import 'package:flutter/material.dart';

class _DocCategory {
  const _DocCategory({required this.titleKey, required this.functions});

  final String titleKey;
  final List<String> functions;
}

/// Functions that have a detailed i18n description key (`bdfd_docs_desc_<key>`).
/// These are either Bot Creator-only or behave differently from standard BDFD.
const Set<String> _describedFunctions = <String>{
  // Bot Creator-only
  'for',
  'loop',
  'callworkflow',
  'workflowresponse',
  'eval',
  // Modified behaviour
  'if',
  'elseif',
  'try',
  'stop',
  'suppresserrors',
  'embedsuppresserrors',
  'and',
  'or',
  'awaitfunc',
  'defer',
  'ephemeral',
  'jsonparse',
  'jsonset',
  'jsonstringify',
  'httpget',
  'httpaddheader',
  'httpresult',
};

const List<_DocCategory> _docCategories = [
  _DocCategory(
    titleKey: 'bdfd_docs_category_messages',
    functions: [
      'sendmessage',
      'channelsendmessage',
      'sendembedmessage',
      'message',
      'editmessage',
      'editin',
      'editembedin',
      'getmessage',
      'deletemessage',
      'deletein',
      'reply',
      'replyin',
      'repeatmessage',
      'dm',
      'tts',
      'pinmessage',
      'publishmessage',
      'unpinmessage',
      'mentioned',
      'mentionedchannels',
    ],
  ),
  _DocCategory(
    titleKey: 'bdfd_docs_category_embeds',
    functions: [
      'title',
      'description',
      'color',
      'footer',
      'footericon',
      'image',
      'thumbnail',
      'author',
      'authoricon',
      'authorurl',
      'embeddedurl',
      'addfield',
      'addtimestamp',
    ],
  ),
  _DocCategory(
    titleKey: 'bdfd_docs_category_components',
    functions: [
      'addbutton',
      'editbutton',
      'newselectmenu',
      'editselectmenu',
      'addselectmenuoption',
      'editselectmenuoption',
      'removecomponent',
      'removeallcomponents',
      'removebuttons',
      'addcontainer',
      'addmediagallery',
      'addsection',
      'addseparator',
      'addtextdisplay',
      'addthumbnail',
    ],
  ),
  _DocCategory(
    titleKey: 'bdfd_docs_category_modals',
    functions: ['newmodal', 'addtextinput'],
  ),
  _DocCategory(
    titleKey: 'bdfd_docs_category_control',
    functions: [
      'if',
      'elseif',
      'onlyif',
      'checkcondition',
      'equals',
      'for',
      'loop',
      'eval',
      'suppresserrors',
      'embedsuppresserrors',
      'callworkflow',
      'workflowresponse',
    ],
  ),
  _DocCategory(
    titleKey: 'bdfd_docs_category_guards',
    functions: [
      'argscheck',
      'checkuserperms',
      'checkusersperms',
      'onlyadmin',
      'onlybotperms',
      'onlybotchannelperms',
      'onlynsfw',
      'onlyperms',
      'onlyforcategories',
      'onlyforchannels',
      'onlyforids',
      'onlyforroleids',
      'onlyforroles',
      'onlyforservers',
      'onlyforusers',
      'onlyifmessagecontains',
      'blacklistids',
      'blacklistroleids',
      'blacklistroles',
      'blacklistrolesids',
      'blacklistservers',
      'blacklistusers',
    ],
  ),
  _DocCategory(
    titleKey: 'bdfd_docs_category_moderation',
    functions: [
      'ban',
      'banid',
      'unban',
      'unbanid',
      'kick',
      'kickmention',
      'mute',
      'timeout',
      'unmute',
      'untimeout',
    ],
  ),
  _DocCategory(
    titleKey: 'bdfd_docs_category_variables',
    functions: [
      'getvar',
      'setvar',
      'var',
      'varexists',
      'getuservar',
      'setuservar',
      'resetuservar',
      'getservervar',
      'setservervar',
      'resetservervar',
      'getchannelvar',
      'setchannelvar',
      'resetchannelvar',
      'getmembervar',
      'setmembervar',
      'resetmembervar',
      'getguildvar',
      'setguildvar',
      'resetguildvar',
      'getguildmembervar',
      'setguildmembervar',
      'resetguildmembervar',
      'getmessagevar',
      'setmessagevar',
    ],
  ),
  _DocCategory(
    titleKey: 'bdfd_docs_category_json',
    functions: [
      'json',
      'jsonparse',
      'jsonset',
      'jsonsetstring',
      'jsonunset',
      'jsonexists',
      'jsonstringify',
      'jsonpretty',
      'jsonclear',
      'jsonarray',
      'jsonarrayappend',
      'jsonarraycount',
      'jsonarrayindex',
      'jsonarraypop',
      'jsonarrayreverse',
      'jsonarrayshift',
      'jsonarraysort',
      'jsonarrayunshift',
      'jsonjoinarray',
    ],
  ),
  _DocCategory(
    titleKey: 'bdfd_docs_category_http',
    functions: [
      'httpget',
      'httppost',
      'httpput',
      'httppatch',
      'httpdelete',
      'httpaddheader',
      'httpresult',
    ],
  ),
  _DocCategory(
    titleKey: 'bdfd_docs_category_math',
    functions: [
      'calculate',
      'sum',
      'sub',
      'multi',
      'divide',
      'modulo',
      'max',
      'min',
      'ceil',
      'floor',
      'round',
      'sqrt',
      'random',
      'randomstring',
      'sort',
    ],
  ),
  _DocCategory(
    titleKey: 'bdfd_docs_category_text',
    functions: [
      'charcount',
      'linescount',
      'contains',
      'checkcontains',
      'croptext',
      'removecontains',
      'removelinks',
      'replacetext',
      'tolowercase',
      'touppercase',
      'totitlecase',
      'trimspace',
      'unescape',
      'textsplit',
      'splittext',
      'editsplittext',
      'removesplittextelement',
      'joinsplittext',
      'gettextsplitindex',
      'numberseparator',
      'randomtext',
      'input',
      'args',
    ],
  ),
  _DocCategory(
    titleKey: 'bdfd_docs_category_channels',
    functions: [
      'createchannel',
      'deletechannels',
      'deletechannelsbyname',
      'modifychannel',
      'modifychannelperms',
      'editchannelperms',
      'slowmode',
      'startthread',
      'threadaddmember',
      'threadremovemember',
      'clear',
      'findchannel',
      'channelexists',
      'channelidfromname',
      'usechannel',
      'usersinchannel',
    ],
  ),
  _DocCategory(
    titleKey: 'bdfd_docs_category_roles',
    functions: [
      'createrole',
      'deleterole',
      'giverole',
      'giveroles',
      'takerole',
      'takeroles',
      'rolegrant',
      'setuserroles',
      'hasrole',
      'colorrole',
      'modifyrole',
      'modifyroleperms',
      'findrole',
      'roleinfo',
      'roleid',
      'rolename',
      'roleperms',
      'roleposition',
      'roleexists',
      'userswithrole',
      'getrolecolor',
    ],
  ),
  _DocCategory(
    titleKey: 'bdfd_docs_category_reactions',
    functions: [
      'addreactions',
      'addcmdreactions',
      'addmessagereactions',
      'clearreactions',
      'getreactions',
      'userreacted',
    ],
  ),
  _DocCategory(
    titleKey: 'bdfd_docs_category_cooldowns',
    functions: [
      'cooldown',
      'servercooldown',
      'globalcooldown',
      'getcooldown',
      'changecooldowntime',
    ],
  ),
  _DocCategory(
    titleKey: 'bdfd_docs_category_webhooks',
    functions: [
      'webhookcreate',
      'webhookdelete',
      'webhooksend',
      'webhookavatarurl',
      'webhookcolor',
      'webhookcontent',
      'webhookdescription',
      'webhookfooter',
      'webhooktitle',
      'webhookusername',
    ],
  ),
  _DocCategory(
    titleKey: 'bdfd_docs_category_leaderboards',
    functions: [
      'userleaderboard',
      'serverleaderboard',
      'globaluserleaderboard',
      'getleaderboardposition',
      'getleaderboardvalue',
    ],
  ),
  _DocCategory(
    titleKey: 'bdfd_docs_category_tickets',
    functions: ['newticket', 'closeticket'],
  ),
  _DocCategory(
    titleKey: 'bdfd_docs_category_misc',
    functions: [
      'addemoji',
      'removeemoji',
      'customemoji',
      'allowmention',
      'allowrolementions',
      'allowusermentions',
      'awaitfunc',
      'bottyping',
      'bytecount',
      'changeusername',
      'changeusernamewithid',
      'creationdate',
      'date',
      'defer',
      'deletecommand',
      'ephemeral',
      'finduser',
      'getattachments',
      'getbanreason',
      'getembeddata',
      'getinviteinfo',
      'getserverinvite',
      'guildexists',
      'hostingexpiretime',
      'isboolean',
      'isinteger',
      'isnumber',
      'isvalidhex',
      'isbanned',
      'isbooster',
      'isbot',
      'isemojianimated',
      'ishoisted',
      'ismentionable',
      'ismentioned',
      'ismessageedited',
      'isnsfw',
      'istimedout',
      'memberid',
      'membernick',
      'emojicount',
      'emojiexists',
      'emojiname',
      'emotecount',
      'stickercount',
      'userexists',
      'userinfo',
      'serverinfo',
    ],
  ),
];

class BdfdDocsPage extends StatefulWidget {
  const BdfdDocsPage({super.key});

  @override
  State<BdfdDocsPage> createState() => _BdfdDocsPageState();
}

class _BdfdDocsPageState extends State<BdfdDocsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1E1E1E) : const Color(0xFF263238),
      appBar: AppBar(
        backgroundColor:
            isDark ? const Color(0xFF252526) : const Color(0xFF37474F),
        title: Text(
          AppStrings.t('bdfd_docs_title'),
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: AppStrings.t('bdfd_docs_search_hint'),
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
                filled: true,
                fillColor:
                    isDark ? const Color(0xFF2D2D2D) : const Color(0xFF37474F),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final lowerQuery = _query.toLowerCase();

    final filteredCategories = <_DocCategory>[];
    for (final category in _docCategories) {
      final filteredFunctions =
          category.functions.where((f) {
            if (lowerQuery.isEmpty) return true;
            return f.contains(lowerQuery) || '\$$f'.contains(lowerQuery);
          }).toList();
      if (filteredFunctions.isNotEmpty) {
        filteredCategories.add(
          _DocCategory(
            titleKey: category.titleKey,
            functions: filteredFunctions,
          ),
        );
      }
    }

    if (filteredCategories.isEmpty) {
      return Center(
        child: Text(
          AppStrings.t('bdfd_docs_empty'),
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      itemCount: filteredCategories.length,
      itemBuilder: (context, index) {
        final category = filteredCategories[index];
        return _buildCategory(category);
      },
    );
  }

  Widget _buildCategory(_DocCategory category) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            AppStrings.t(category.titleKey),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade200,
            ),
          ),
        ),
        ...category.functions.map(_buildFunctionCard),
      ],
    );
  }

  Widget _buildFunctionCard(String funcKey) {
    final params = bdfdSignatureHints[funcKey];
    final hasParams = params != null && params.isNotEmpty;
    final displayName =
        hasParams ? '\$$funcKey[${params.join('; ')}]' : '\$$funcKey';
    final hasDescription = _describedFunctions.contains(funcKey);
    final descKey = 'bdfd_docs_desc_$funcKey';

    return Card(
      color: const Color(0xFF253341),
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        iconColor: Colors.grey.shade400,
        collapsedIconColor: Colors.grey.shade600,
        title: Row(
          children: [
            Expanded(
              child: Text(
                '\$$funcKey',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: Color(0xFFFF9800),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (hasDescription)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade700.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Bot Creator',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ),
          ],
        ),
        children: [
          if (hasDescription) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade900.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.deepPurple.shade700.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                AppStrings.t(descKey),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
            ),
          ],
          if (hasParams) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppStrings.t('bdfd_docs_syntax'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2530),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                displayName,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFFE0E0E0),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppStrings.t('bdfd_docs_parameters'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
            const SizedBox(height: 4),
            ...params.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        p,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color:
                              p.contains('(opt)')
                                  ? Colors.grey.shade500
                                  : Colors.white70,
                          fontStyle:
                              p.contains('(opt)')
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppStrings.t('bdfd_docs_no_params'),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
