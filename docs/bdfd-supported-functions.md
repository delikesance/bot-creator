# Fonctions BDFD supportees dans Bot Creator

Etat de reference: 30/03/2026.

Ce document decrit ce qui est pris en charge par le transpiler BDFD de Bot Creator.

## Niveaux de support

- Support complet: transpilation dediee vers action(s) runtime attendues.
- Support transpilation placeholder: la fonction est resolue en placeholder texte `((...))`.
- Support partiel: accepte syntaxe/fonction, mais comportement simplifie ou differant de BDFD.
- Non supporte: diagnostic `Unsupported BDFD function for action transpilation`.

## Fonctions supportees (actions)

### Controle de flux

- if
- onlyIf
- onlyForUsers
- onlyForIDs
- onlyForChannels
- onlyForRoles
- onlyForRoleIDs
- onlyForServers
- onlyForCategories
- ignoreChannels
- onlyNSFW
- onlyAdmin
- onlyPerms
- onlyBotPerms
- onlyBotChannelPerms
- checkUserPerms
- checkUsersPerms
- onlyIfMessageContains
- stop

### Bloc conditionnel

- if ... elseif ... else ... endif

### Boucles bloc

- for[n] ... endfor
- loop[n] ... endloop

Note: deroulage compile-time avec limite de securite.

### Messagerie

- reply
- sendMessage
- channelSendMessage

### Composants / Interactions

- addButton
- addSelectMenuOption
- addSeparator
- addTextDisplay
- addTextInput
- editButton
- editSelectMenu
- editSelectMenuOption
- newModal
- newSelectMenu
- removeAllComponents / removeAllComponents[]
- removeButtons / removeButtons[]
- removeComponent
- defer
- input

### Embeds

- title
- description
- color
- footer (avec footerIcon optionnel en arg 2)
- footerIcon (standalone)
- thumbnail
- image
- author (avec authorIcon en arg 2, authorURL en arg 3)
- authorIcon (standalone)
- authorURL (standalone)
- addField
- addTimestamp / addTimestamp[]
- embeddedURL
- addContainer
- addSection
- addThumbnail

### Threads

- startThread
- editThread
- threadAddMember
- threadRemoveMember

### HTTP

- httpAddHeader
- httpGet
- httpPost
- httpPut
- httpDelete
- httpPatch

### Variables scopees

- setUserVar
- setServerVar
- setGuildVar
- setChannelVar
- setMemberVar
- setGuildMemberVar
- setMessageVar
- getUserVar (inline)
- getServerVar (inline)
- getGuildVar (inline)
- getChannelVar (inline)
- getMemberVar (inline)
- getGuildMemberVar (inline)
- getMessageVar (inline)

### JSON helpers

- jsonParse
- jsonSet
- jsonSetString
- jsonUnset
- jsonClear
- jsonArray
- jsonArrayAppend
- jsonArrayUnshift
- jsonArraySort
- jsonArrayReverse
- json (inline)
- jsonExists (inline)
- jsonStringify (inline)
- jsonPretty (inline)
- jsonArrayCount (inline)
- jsonArrayIndex (inline)
- jsonJoinArray (inline)
- jsonArrayPop (inline)
- jsonArrayShift (inline)

### Await

- awaitFunc

### Profil bot

- changeUsername
- changeUsernameWithID

## Fonctions supportees (placeholder inline)

### Message/mentions

- message
- message[]
- mentionedChannels

### Runtime placeholders alias

- userID
- username / username[userID]
- userTag
- userAvatar
- userBanner
- authorID
- authorOfMessage
- authorAvatar
- authorUsername
- authorTag
- authorBanner
- creationDate
- discriminator
- displayName / displayName[userID]
- getUserStatus
- getCustomStatus
- isAdmin
- isBooster
- isBot
- isUserDMEnabled
- nickname / nickname[userID]
- userBadges
- userBannerColor
- userExists
- userInfo
- userJoined
- userJoinedDiscord
- userPerms
- userServerAvatar
- findUser
- guildID
- guildName
- guildIcon
- guildCount
- memberCount
- serverID
- serverName
- serverIcon
- channelID
- channelName
- channelType
- commandName
- commandType

## Fonctions non supportees

Toute fonction absente des listes ci-dessus est non supportee pour le moment et genere un diagnostic de transpilation.

## Notes importantes vs BDFD

- Certaines fonctions de type "placeholder" sont mappees vers des variables runtime Bot Creator. Le rendu depend donc de la disponibilite effective des variables dans le contexte d execution.
- Certaines variantes BDFD avec arguments optionnels (par exemple displayName[userID], nickname[userID], username[userID]) sont resolues vers des placeholders cibles: `((user[id].username))`, `((member[id].nick))`, `((member[id].nick|user[id].username))`.
- checkUserPerms est supportee en mode guard et en mode inline (booleen via variable message temporaire).
