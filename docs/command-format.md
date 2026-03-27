# Format des Commandes — Référence V1

Ce document décrit le format JSON des commandes tel qu'il est:

- stocké sur disque par l'app
- normalisé au chargement
- réutilisé par le runtime local et le Runner

Cette version documente aussi:

- `fieldsTemplate` pour les embeds dynamiques
- le bloc `autocomplete` des options de commande

---

## 1. Fichier de commande sur disque

Chaque commande est stockée sous la forme:

```jsonc
{
  "name": "ma-commande",
  "description": "Description slash",
  "type": "chatInput", // chatInput | user | message
  "id": "123456789",
  "createdAt": "2026-03-23T12:00:00.000Z",
  "data": { /* CommandData */ }
}
```

Le champ racine `type` correspond au type Discord de la commande.

---

## 2. `data` / `CommandData`

```jsonc
{
  "version": 1,
  "commandType": "chatInput", // chatInput | user | message
  "editorMode": "simple",     // ou "advanced"
  "defaultMemberPermissions": "",
  "simpleConfig": { /* SimpleConfig */ },
  "options": [ /* CommandOption[] */ ],
  "response": { /* Response */ },
  "actions": [ /* Action[] */ ],
  "subcommandWorkflows": {
    "admin/ban": {
      "response": { /* Response */ },
      "actions": [ /* Action[] */ ]
    }
  },
  "activeSubcommandRoute": "admin/ban"
}
```

Règles:

- `options` n'a de sens que pour `chatInput`
- `user` et `message` ignorent `description` et `options` côté Discord
- si `commandType` est absent, la normalisation fallback sur `chatInput`

---

## 3. Réponse principale

```jsonc
{
  "mode": "text", // ou "embed"
  "type": "normal", // normal | ephemeral | componentV2
  "text": "Bonjour ((userName))",
  "embed": { /* legacy */ },
  "embeds": [ /* Embed[] */ ],
  "components": { /* ComponentV2Definition */ },
  "modal": { /* ModalDefinition */ },
  "workflow": { /* Workflow config */ }
}
```

`embed` reste le champ legacy. À la normalisation:

- si `embeds` est vide mais `embed` contient des données, `embed` est migré vers `embeds[0]`
- la réponse limite toujours à 10 embeds

---

## 4. Format d'un embed

Tous les champs string passent par le moteur de template.

```jsonc
{
  "title": "((guildName)) — Classement",
  "description": "Top actuel",
  "url": "https://example.com",
  "color": "#5865F2",
  "timestamp": "2026-03-23T12:00:00.000Z",
  "image": {
    "url": "((userAvatar))"
  },
  "thumbnail": {
    "url": "((opts.user.avatar))"
  },
  "footer": {
    "text": "Demandé par ((userName))",
    "icon_url": "((userAvatar))"
  },
  "author": {
    "name": "((userName))",
    "url": "https://example.com/profile",
    "icon_url": "((userAvatar))"
  },
  "fields": [
    {
      "name": "Statique",
      "value": "Toujours présent",
      "inline": false
    }
  ],
  "fieldsTemplate": "((embedFields(search.body.$.items, \"{name}\", \"{score}\", true)))"
}
```

### `fields`

`fields` reste la liste statique classique.

### `fieldsTemplate`

`fieldsTemplate` est une nouveauté V1.

Règles:

- le champ est résolu comme un template normal
- le résultat doit être un JSON array de fields
- chaque entrée doit contenir au minimum `name` et `value`
- `inline` est optionnel, booléen
- les fields dynamiques sont ajoutés après les fields statiques
- une ligne invalide, vide ou un JSON mal formé est ignoré sans casser tout l'embed

Format attendu après résolution:

```json
[
  { "name": "Alice", "value": "12", "inline": true },
  { "name": "Bob", "value": "10", "inline": true }
]
```

Limites:

- maximum 25 fields par embed
- maximum 10 embeds par message

---

## 5. Options de commande

Une option stockée localement ressemble à ceci:

```jsonc
{
  "type": "string",
  "name": "country",
  "description": "Country name",
  "required": false,
  "choices": [
    { "name": "France", "value": "fr" }
  ]
}
```

Types supportés:

- `string`
- `integer`
- `number`
- `boolean`
- `user`
- `channel`
- `role`
- `mentionable`
- `attachment`
- `subCommand`
- `subCommandGroup`

---

## 6. Auto-complete dynamique

Pour les options `string`, `integer` et `number`, un bloc `autocomplete` peut
être stocké localement:

```jsonc
{
  "type": "string",
  "name": "country",
  "description": "Country name",
  "required": false,
  "autocomplete": {
    "enabled": true,
    "workflow": "country_search",
    "entryPoint": "main",
    "arguments": {
      "dataset": "countries"
    }
  }
}
```

Règles:

- `autocomplete.enabled = true` désactive les `choices` statiques
- lors de la publication Discord, l'option est marquée `hasAutocomplete`
- côté stockage local, le bloc complet `autocomplete` est conservé
- le workflow référencé est un workflow général existant
- le workflow d'auto-complete doit finir par `respondWithAutocomplete`

Exclusion mutuelle:

- si `autocomplete` est activé, `choices` n'est pas sérialisé

---

## 7. Structure d'une action

```jsonc
{
  "type": "queryArray",
  "key": "scores",
  "enabled": true,
  "depend_on": [],
  "error": {},
  "payload": {
    "input": "((search.body))",
    "path": "$.items",
    "filterTemplate": "{score}",
    "filterOperator": "gte",
    "filterValue": "10",
    "sortTemplate": "{name}",
    "order": "desc",
    "offset": 0,
    "limit": 10,
    "storeAs": "bestScores"
  }
}
```

Tous les champs string de payload qui passent par le runtime peuvent contenir
des templates `((...))`.

### `ifBlock`

Branche l'exécution entre un bloc THEN, zéro ou plusieurs blocs ELSE IF, puis un
bloc ELSE final.

Payload typique:

```jsonc
{
  "condition.variable": "((score))",
  "condition.operator": "greaterThan",
  "condition.value": "90",
  "thenActions": [
    { "type": "sendMessage", "payload": { "content": "Excellent" } }
  ],
  "elseIfConditions": [
    {
      "condition.variable": "((score))",
      "condition.operator": "greaterThan",
      "condition.value": "70",
      "actions": [
        { "type": "sendMessage", "payload": { "content": "Good" } }
      ]
    }
  ],
  "elseActions": [
    { "type": "sendMessage", "payload": { "content": "Try again" } }
  ]
}
```

Règles:

- `thenActions` reste la branche IF principale
- `elseIfConditions` est une liste ordonnée; la première condition vraie gagne
- `elseActions` reste la branche finale par défaut
- les anciens workflows sans `elseIfConditions` restent valides

---

## 8. Nouvelles actions JSON / arrays

### `appendArrayElement`

Ajoute un élément dans une variable globale ou scopée.

Payload typique:

```jsonc
{
  "target": "scoped",   // global | scoped
  "scope": "guild",
  "key": "leaderboard",
  "path": "$.items",
  "valueType": "json",  // string | number | boolean | json
  "jsonValue": "{\"name\":\"Alice\",\"score\":12}"
}
```

Sorties runtime:

- `<key>.items`
- `<key>.length`

### `removeArrayElement`

Retire un élément par index.

Payload typique:

```jsonc
{
  "target": "global",
  "key": "queue",
  "path": "$",
  "index": 0
}
```

Sorties runtime:

- `<key>.items`
- `<key>.length`
- `<key>.removed`

### `queryArray`

Filtre, trie et page n'importe quel array JSON runtime.

Payload typique:

```jsonc
{
  "input": "((search.body))",
  "path": "$.items",
  "filterTemplate": "{score}",
  "filterOperator": "gte",
  "filterValue": "10",
  "sortTemplate": "{name}",
  "order": "desc",
  "offset": 0,
  "limit": 10,
  "storeAs": "bestScores"
}
```

Opérateurs supportés:

- `contains`
- `equals`
- `startsWith`
- `endsWith`
- `gt`
- `gte`
- `lt`
- `lte`

Sorties runtime:

- `<key>.items`
- `<key>.count`
- `<key>.total`
- alias `storeAs` si fourni

### `respondWithAutocomplete`

Répond à une interaction Discord d'auto-complete.

Payload typique:

```jsonc
{
  "items": "((bestScores))",
  "path": "$",
  "labelTemplate": "{name}",
  "valueTemplate": "{id}"
}
```

Règles:

- utilisable uniquement dans un workflow d'auto-complete
- limite forcée à 25 choix
- le type final (`string`, `integer`, `number`) dépend de l'option focusée

---

## 9. Cycle de vie simplifié

```txt
[Éditeur App]
  -> sauvegarde locale du JSON complet
  -> publication Discord avec options / hasAutocomplete
  -> interaction reçue
  -> hydratation des variables runtime
  -> résolution des templates
  -> exécution des actions
  -> réponse Discord
```

Pour l'auto-complete:

```txt
Interaction autocomplete
  -> lecture de l'option focusée
  -> récupération du bloc autocomplete stocké
  -> exécution du workflow référencé
  -> respondWithAutocomplete
```

---

## 10. Pièges et règles importantes

| Sujet | Règle |
|-------|-------|
| `editorMode` | doit rester dans `data` |
| `commandType` absent | fallback automatique sur `chatInput` |
| `user` / `message` | ignorent `description` et `options` côté Discord |
| `fieldsTemplate` invalide | ignoré sans casser l'embed |
| `autocomplete.enabled=true` | rend `choices` indisponible |
| URL d'embed invalide | champ ignoré silencieusement |
| variable inconnue | remplacée par `""` |

---

## 11. Exemple compact complet

```jsonc
{
  "name": "leaderboard",
  "description": "Show leaderboard",
  "type": "chatInput",
  "data": {
    "version": 1,
    "commandType": "chatInput",
    "editorMode": "advanced",
    "options": [
      {
        "type": "string",
        "name": "country",
        "description": "Country filter",
        "required": false,
        "autocomplete": {
          "enabled": true,
          "workflow": "country_search",
          "entryPoint": "main",
          "arguments": {
            "dataset": "countries"
          }
        }
      }
    ],
    "response": {
      "mode": "embed",
      "type": "normal",
      "text": "",
      "embeds": [
        {
          "title": "Classement",
          "fieldsTemplate": "((embedFields(scores.items.$, \"{name}\", \"{score}\", true)))"
        }
      ]
    },
    "actions": [
      {
        "type": "queryArray",
        "key": "scores",
        "payload": {
          "input": "((httpSearch.body))",
          "path": "$.items",
          "sortTemplate": "{score}",
          "order": "desc",
          "limit": 10
        }
      }
    ]
  }
}
```
