# Variables Runtime — Référence complète

Les variables runtime sont résolues dans les templates via la syntaxe
`((nomDeLaVariable))`. Elles sont injectées par l'app locale et par le Runner
au moment de l'exécution.

Cette V1 ajoute deux points importants:

- les variables stockées peuvent contenir du JSON complet, y compris arrays et objets
- les workflows d'auto-complete exposent un contexte runtime dédié

> Sources:
> `packages/shared/lib/utils/global.dart`
> `packages/shared/lib/utils/runtime_variables.dart`
> `packages/shared/lib/utils/template_resolver.dart`

---

## 1. Variables globales toujours disponibles

| Variable | Valeur |
|----------|--------|
| `((userName))` | Nom de l'utilisateur ayant déclenché l'interaction |
| `((userId))` | ID utilisateur |
| `((userUsername))` | Username Discord |
| `((userTag))` | Discriminant ou `0` |
| `((userAvatar))` | URL avatar |
| `((userBanner))` | URL bannière utilisateur quand disponible |
| `((author.id))` | Alias de l'ID de l'auteur |
| `((author.username))` | Alias du username de l'auteur |
| `((author.tag))` | Alias du tag de l'auteur |
| `((author.avatar))` | Alias de l'avatar de l'auteur |
| `((author.banner))` | Alias de la bannière de l'auteur |
| `((interaction.user.id))` | Alias runtime de l'ID auteur |
| `((interaction.user.username))` | Alias runtime du username auteur |
| `((interaction.user.tag))` | Alias runtime du tag auteur |
| `((interaction.user.avatar))` | Alias runtime de l'avatar auteur |
| `((interaction.user.banner))` | Alias runtime de la bannière auteur |
| `((member.id))` | ID membre courant |
| `((member.nick))` | Surnom membre courant |
| `((member.avatar))` | Avatar membre (guild) quand disponible |
| `((channel.name))` | Alias structuré du nom du salon |
| `((channel.id))` | Alias structuré de l'ID du salon |
| `((channel.type))` | Alias structuré du type du salon |
| `((guild.name))` | Alias structuré du nom serveur |
| `((guild.id))` | Alias structuré de l'ID serveur |
| `((guild.count))` | Alias structuré du nombre de membres |
| `((interaction.channel.id))` | Alias runtime channel ID |
| `((interaction.channel.name))` | Alias runtime channel name |
| `((interaction.channel.type))` | Alias runtime channel type |
| `((interaction.guild.id))` | Alias runtime guild ID |
| `((interaction.guild.name))` | Alias runtime guild name |
| `((interaction.guild.icon))` | Alias runtime guild icon |
| `((guildName))` | Nom du serveur |
| `((guildId))` | ID du serveur |
| `((guildCount))` | Nombre de membres approx. |
| `((guildIcon))` | URL icône serveur |
| `((channelName))` | Nom du salon |
| `((channelId))` | ID du salon |
| `((channelType))` | Type de salon |
| `((commandName))` | Nom de la commande |
| `((commandId))` | ID de la commande |
| `((commandType))` | `chatInput`, `user`, `message` |
| `((commandTypeValue))` | Valeur Discord brute |
| `((command.type))` | Alias textuel |
| `((interaction.command.type))` | Alias runtime textuel |
| `((interaction.command.route))` | Route de sous-commande résolue, ex: `admin/ban` |

---

## 2. Options de commande slash

Chaque option expose un préfixe `opts.<nomOption>`.

### Types simples

| Variable | Valeur |
|----------|--------|
| `((opts.<nom>))` | Valeur brute d'une option `string`, `integer`, `number`, `boolean` |

### Option `user`

| Variable | Valeur |
|----------|--------|
| `((opts.<nom>))` | Username / nom |
| `((opts.<nom>.id))` | ID utilisateur |
| `((opts.<nom>.username))` | Username explicite |
| `((opts.<nom>.tag))` | Tag / discriminant |
| `((opts.<nom>.avatar))` | URL avatar |
| `((opts.<nom>.banner))` | URL bannière quand disponible |

### Option `channel`

| Variable | Valeur |
|----------|--------|
| `((opts.<nom>))` | Nom du salon |
| `((opts.<nom>.id))` | ID du salon |
| `((opts.<nom>.type))` | Type du salon |

### Option `role`

| Variable | Valeur |
|----------|--------|
| `((opts.<nom>))` | Nom du rôle |
| `((opts.<nom>.id))` | ID du rôle |

### Option `mentionable`

| Variable | Valeur |
|----------|--------|
| `((opts.<nom>))` | Libellé principal |
| `((opts.<nom>.id))` | ID cible |
| `((opts.<nom>.avatar))` | URL avatar quand disponible |

Les sous-commandes exposent aussi leurs arguments via `opts.*`.

---

## 3. Commandes `user` et `message`

### Commandes `user`

| Variable | Valeur |
|----------|--------|
| `((target.id))` | ID cible |
| `((interaction.target.id))` | Alias |
| `((target.user.id))` | ID utilisateur ciblé |
| `((target.user.username))` | Username ciblé |
| `((target.user.tag))` | Tag ciblé |
| `((target.user.avatar))` | Avatar ciblé |
| `((target.userName))` | Alias court |
| `((target.userAvatar))` | Alias court |
| `((target.member.id))` | ID membre si disponible |
| `((target.member.nick))` | Surnom si disponible |

### Commandes `message`

| Variable | Valeur |
|----------|--------|
| `((target.id))` | ID cible |
| `((interaction.target.id))` | Alias |
| `((target.message.id))` | ID du message ciblé |
| `((target.message.channelId))` | ID du salon du message |
| `((target.message.content))` | Contenu du message |
| `((target.message.author.id))` | ID auteur |
| `((target.messageId))` | Alias court |
| `((target.messageContent))` | Alias court |

---

## 4. Interactions `component` et `modal`

Les listeners de composants et modals injectent maintenant le même socle
runtime que les commandes pour l'auteur, le membre, le salon et le serveur.

Variables communes utiles:

| Variable | Valeur |
|----------|--------|
| `((interaction.customId))` | Custom ID du composant cliqué |
| `((modal.customId))` | Custom ID du modal soumis |
| `((interaction.user.id))` | ID utilisateur déclencheur |
| `((interaction.user.username))` | Username déclencheur |
| `((interaction.user.avatar))` | Avatar utilisateur |
| `((interaction.user.banner))` | Bannière utilisateur (si disponible) |
| `((interaction.member.nick))` | Nickname membre (si disponible) |
| `((interaction.member.avatar))` | Avatar membre (guild) |
| `((interaction.channel.id))` | ID salon |
| `((interaction.channel.name))` | Nom salon |
| `((interaction.channel.type))` | Type salon |
| `((interaction.guild.id))` | ID serveur |
| `((interaction.guild.name))` | Nom serveur |
| `((interaction.guild.icon))` | URL icône serveur |
| `((interaction.values))` | Valeurs sélectionnées (select menu, CSV) |
| `((modal.<inputCustomId>))` | Valeur d'un champ texte du modal |

Les aliases `author.*`, `user.*`, `member.*`, `channel.*`, `guild.*` sont
aussi disponibles sur ces interactions.

### Mode routeur permanent via event `interactionCreate`

Dans un workflow event déclenché sur `interactionCreate`, les variables
suivantes permettent de router les clics boutons/menus/modals sans listener TTL:

| Variable | Valeur |
|----------|--------|
| `((interaction.kind))` | `button`, `select`, `modal`, `command`, `autocomplete` |
| `((interaction.customId))` | Custom ID du composant/modal |
| `((interaction.values))` | Valeurs du select (CSV) |
| `((interaction.values.count))` | Nombre de valeurs sélectionnées |
| `((modal.<inputCustomId>))` | Valeur d'un champ texte modal |
| `((interaction.channelId))` | ID channel interaction |
| `((interaction.guildId))` | ID guild interaction |
| `((interaction.userId))` | ID user interaction |
| `((interaction.messageId))` | ID message source si présent |

Champs avancés normalisés (quand disponibles):

- `((channel.kind))`, `((channel.topic))`, `((channel.parentId))`, `((channel.position))`
- `((channel.nsfw))`, `((channel.slowmode))`, `((channel.bitrate))`, `((channel.userLimit))`
- `((channel.thread.archived))`, `((channel.thread.locked))`, `((channel.thread.ownerId))`, `((channel.thread.autoArchiveDuration))`
- `((guild.kind))`, `((guild.ownerId))`, `((guild.description))`, `((guild.vanityUrlCode))`
- `((guild.preferredLocale))`, `((guild.verificationLevel))`, `((guild.mfaLevel))`, `((guild.nsfwLevel))`
- `((guild.premiumTier))`, `((guild.premiumSubscriptionCount))`, `((guild.features))`, `((guild.features.count))`, `((guild.memberCount))`

---

## 5. Variables stockées persistées

Les variables persistées sont hydratées dans le runtime au début d'un workflow.

### Variables globales

Accès:

```txt
((global.<key>))
```

Exemples:

```txt
((global.settings))
((global.settings.$.locale))
((global.inventory.$[0].name))
```

### Variables scopées

Scopes supportés:

- `guild`
- `user`
- `channel`
- `guildMember`
- `message`

Accès:

```txt
((guild.bc_<key>))
((user.bc_<key>))
((channel.bc_<key>))
```

Compatibilité:

- la forme `bc_<key>` reste l'alias runtime principal
- selon le contexte, l'éditeur et certaines actions acceptent aussi le nom nu

Types supportés:

- `string`
- `number`
- `boolean`
- `json`

Le type `json` permet de stocker directement:

- un objet
- un array
- un objet contenant des arrays

Exemples:

```txt
((guild.bc_settings.$.logs.channelId))
((guild.bc_leaderboard.$[0].userId))
((user.bc_profile.$.tags[1]))
```

---

## 6. Variables issues d'actions

Les actions avec `key` exposent souvent leurs sorties dans le runtime.

### `httpRequest`

Exemple avec `key: "search"`:

| Variable | Valeur |
|----------|--------|
| `((search.body))` | corps brut |
| `((search.body.$.items))` | array JSON sérialisé |
| `((search.body.$.items[0].name))` | champ extrait |

### `listScopedVariableIndex`

Exemple avec `key: "classement"`:

| Variable | Valeur |
|----------|--------|
| `((classement.items))` | liste JSON des entrées |
| `((classement.count))` | nombre d'éléments renvoyés |
| `((classement.total))` | total indexé |

### `appendArrayElement`

Exemple avec `key: "appendScore"`:

| Variable | Valeur |
|----------|--------|
| `((appendScore.items))` | array mis à jour |
| `((appendScore.length))` | longueur après ajout |

### `removeArrayElement`

Exemple avec `key: "removeScore"`:

| Variable | Valeur |
|----------|--------|
| `((removeScore.items))` | array restant |
| `((removeScore.length))` | longueur restante |
| `((removeScore.removed))` | élément supprimé |

### `queryArray`

Exemple avec `key: "topScores"`:

| Variable | Valeur |
|----------|--------|
| `((topScores.items))` | page courante en JSON |
| `((topScores.count))` | taille de la page |
| `((topScores.total))` | total après filtre |

Si `storeAs` est fourni, l'array paginé est aussi copié dans l'alias demandé.

Exemple:

```txt
queryArray key=topScores storeAs=best
((best))
((best.$[0].name))
```

---

## 6. Variables dédiées à l'auto-complete

Lorsqu'une option de commande utilise l'autocomplete dynamique, le workflow
appelé reçoit ces variables:

| Variable | Valeur |
|----------|--------|
| `((autocomplete.query))` | texte actuellement saisi par l'utilisateur |
| `((autocomplete.optionName))` | nom de l'option focusée |
| `((autocomplete.optionType))` | type de l'option focusée (`string`, `integer`, `number`) |

Les autres options déjà remplies par Discord restent accessibles via `opts.*`
quand elles sont présentes dans l'interaction.

Exemple:

```txt
Recherche: ((autocomplete.query))
Option: ((autocomplete.optionName))
```

---

## 7. Exemples utiles avec arrays

### Lire une réponse HTTP et la formater

```txt
((formatEach(search.body.$.items, "{name} ({score})", "\n")))
```

### Lire un array stocké dans une variable globale

```txt
((join(global.tags.$, ", ")))
```

### Lire le premier objet d'une variable scopée JSON

```txt
((guild.bc_inventory.$[0].name))
```

### Formater un résultat de `queryArray`

```txt
((formatEach(topScores.items.$, "{name}: {score}", "\n")))
```

---

## 8. Bonnes pratiques

- Préférez `global.<key>` et les scopes `guild.bc_<key>` / `user.bc_<key>`
  pour les variables persistées
- Stockez les structures complexes en `json`, pas en string manuelle
- Pour les arrays d'objets, utilisez `formatEach(...)` ou `embedFields(...)`
- Pour l'auto-complete, terminez le workflow par `respondWithAutocomplete`
- En cas de doute sur le contenu d'une variable JSON, testez d'abord:

```txt
((maVariable))
```

puis un chemin plus précis:

```txt
((maVariable.$.items[0]))
```
