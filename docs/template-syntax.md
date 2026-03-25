# Syntaxe des Templates — Référence V1

Le moteur de templates résout les placeholders `((...))` dans les champs texte
qui passent par le runtime: réponses, embeds, payloads d'actions, arguments de
workflow, etc.

Cette V1 traite désormais les arrays et objets JSON comme des données de premier
rang. Une expression peut donc lire du JSON, en extraire un sous-chemin,
appliquer des fonctions, puis réinjecter le résultat sous forme de texte ou de
JSON sérialisé.

> Source: `packages/shared/lib/utils/template_resolver.dart`

---

## 1. Syntaxe de base

```txt
((nomDeLaVariable))
```

- Délimiteurs: `((` et `))`
- Recherche de variable insensible à la casse
- Priorité à la clé exacte, puis fallback insensible à la casse
- Une variable inconnue est remplacée par `""`

Exemples:

```txt
((userName))
((global.score))
((guild.bc_settings))
```

---

## 2. Fallback avec `|`

Le séparateur `|` reste supporté, mais uniquement comme fallback au niveau
racine de l'expression.

```txt
((opts.user|userName))
((target.user.username|userName))
```

Règles:

- Le moteur teste chaque candidat de gauche à droite
- La première valeur résolue est utilisée
- Si rien n'est trouvé, le résultat est `""`
- `|` n'est pas une pipeline de fonctions

Exemple:

```txt
((join(scores.$, ", ")|Aucun score))
```

Ici, `|Aucun score` est un fallback global sur toute l'expression.

---

## 3. Lecture JSON avec JSONPath

Le sous-ensemble JSONPath supporté reste volontairement simple:

- `$` pour la racine
- `.champ` pour un accès objet
- `[0]` pour un index de tableau

Exemples:

```txt
((monHttp.body.$.items[0].name))
((classement.items.$[0].value))
((global.profile.$.stats.level))
((guild.bc_inventory.$[2]))
```

Format générique:

```txt
<variable>.$.<chemin>
```

Exemples courants:

```txt
((httpRequest.body.$.data))
((query.items.$[0].id))
((global.settings.$.channels.logs))
```

Résultat final:

- `string` -> injecté tel quel
- `number` / `bool` -> converti en string
- `array` / `object` -> sérialisé en JSON
- `null`, chemin absent, JSON invalide -> `""`

---

## 4. Fonctions d'expression

Le moteur supporte maintenant des fonctions explicites.

Syntaxe:

```txt
((fonction(arg1, arg2, ...)))
```

Arguments autorisés:

- variable runtime
- expression JSONPath
- littéral string entre guillemets
- littéral number
- littéral `true`, `false`, `null`
- autre fonction imbriquée

Exemples:

```txt
((length(scores.$)))
((at(scores.$, 0)))
((slice(scores.$, 0, 5)))
((join(scores.$, ", ")))
((formatEach(scores.$, "{name}: {score}", "\n")))
((embedFields(scores.$, "{name}", "{score}", true)))
((avatar(interaction.user.avatar, "webp", 1024)))
((banner(target.user.banner, "png", 512)))
```

### Fonctions V1

| Fonction | Rôle | Exemple |
|----------|------|---------|
| `length(source)` | Taille d'une string, array ou map | `((length(query.items.$)))` |
| `at(source, index)` | Lit un élément d'array | `((at(query.items.$, 0)))` |
| `slice(source, start, end?)` | Sous-tableau ou sous-chaîne | `((slice(names.$, 0, 3)))` |
| `join(source, separator)` | Concatène un array | `((join(tags.$, ", ")))` |
| `formatEach(source, itemTemplate, separator)` | Formate chaque item | `((formatEach(users.$, "{name}", ", ")))` |
| `embedFields(source, nameTemplate, valueTemplate, inline?)` | Génère un JSON array de fields d'embed | `((embedFields(scores.$, "{name}", "{score}", true)))` |
| `avatar(url, format?, size?)` | Re-formate une URL avatar Discord | `((avatar(interaction.user.avatar, "png", 256)))` |
| `banner(url, format?, size?)` | Re-formate une URL bannière Discord | `((banner(interaction.user.banner, "webp", 1024)))` |

---

## 5. Placeholders d'item pour les arrays

`formatEach(...)` et `embedFields(...)` introduisent des placeholders item:

- `{value}` cible l'item courant
- `{field}` cible une propriété simple
- `{field.subField}` cible une propriété imbriquée

Exemples:

```txt
((formatEach(scores.$, "{name}: {score}", ", ")))
((formatEach(users.$, "{profile.username}", "\n")))
((embedFields(scores.$, "{name}", "{score}", true)))
```

Si l'item courant est un scalaire:

```txt
((formatEach(tags.$, "#{value}", ", ")))
```

---

## 6. Règles de rendu final

Après évaluation d'une expression:

- valeur string -> injectée telle quelle
- valeur number / bool -> `toString()`
- valeur array / object -> JSON sérialisé
- expression invalide -> `""`

Exemples:

```txt
((length(scores.$)))              -> 3
((at(scores.$, 0)))               -> {"name":"Alice","score":12}
((slice(tags.$, 1, 3)))           -> ["beta","gamma"]
((embedFields(scores.$, "{name}", "{score}", true)))
                                  -> [{"name":"Alice","value":"12","inline":true}]
```

---

## 7. Exemples complets

### Texte simple

```txt
Bonjour ((userName)), bienvenue sur ((guildName)) !
```

### Fallback

```txt
Utilisateur ciblé: ((opts.user|userName))
```

### Lecture JSON HTTP

```txt
Premier joueur: ((search.body.$.items[0].name))
```

### Join d'un array

```txt
Joueurs: ((join(search.body.$.items, ", ")))
```

Si `items` contient des strings, le rendu sera direct.
Si `items` contient des objets, préférez `formatEach(...)`.

### Formatage textuel d'objets

```txt
((formatEach(search.body.$.items, "{name} ({score})", "\n")))
```

### Création de fields d'embed

```json
{
  "title": "Classement",
  "fieldsTemplate": "((embedFields(search.body.$.items, \"{name}\", \"{score}\", true)))"
}
```

---

## 8. Champs URL d'embed

Les champs URL d'embed passent toujours par `resolveEmbedUri()`.

Champs concernés:

- `image.url`
- `thumbnail.url`
- `footer.icon_url`
- `author.url`
- `author.icon_url`

Règle:

- le template est d'abord résolu
- le résultat doit être une URL valide avec scheme `http://` ou `https://`
- sinon le champ est ignoré silencieusement

Exemple valide:

```json
{ "thumbnail": { "url": "((userAvatar))" } }
```

Exemple ignoré:

```json
{ "thumbnail": { "url": "((avatar))" } }
```

---

## 9. Exemples prêts à copier

### Carte auteur (slash/component/modal)

```txt
Auteur: ((author.username|userName))
ID: ((author.id|userId))
Avatar 256: ((avatar(author.avatar, "png", 256)))
Banner 1024: ((banner(author.banner, "webp", 1024)))
```

### Option user enrichie

```txt
Utilisateur ciblé: ((opts.user.username|opts.user|userName))
Tag: ((opts.user.tag|userTag))
Avatar: ((avatar(opts.user.avatar, "webp", 512)))
```

### Diagnostic channel avancé

```txt
Salon: ((channel.name|channelName))
Type: ((channel.type|channelType))
Topic: ((channel.topic|"no-topic"))
NSFW: ((channel.nsfw|false))
Slowmode: ((channel.slowmode|0))
```

### Diagnostic guild avancé

```txt
Serveur: ((guild.name|guildName))
Owner: ((guild.ownerId|"unknown"))
Features: ((guild.features|"none"))
Feature count: ((guild.features.count|0))
```

---

## 10. Comportements importants

| Situation | Résultat |
|-----------|----------|
| Variable connue | valeur résolue |
| Variable inconnue | `""` |
| Fallback avec valeur trouvée | première valeur trouvée |
| JSONPath absent | `""` |
| JSON invalide | `""` |
| Fonction invalide | `""` |
| Array/object final | JSON sérialisé |
| URL embed sans scheme | champ ignoré |

---

## 11. Bonnes pratiques

- Utilisez `formatEach(...)` pour du texte lisible à partir d'objets JSON
- Utilisez `embedFields(...)` pour construire dynamiquement des fields
- Réservez `|` au fallback global, pas à une logique de transformation
- Quand une réponse HTTP renvoie un array d'objets, préférez:

```txt
((formatEach(monHttp.body.$.items, "{name}", ", ")))
```

plutôt que des index manuels:

```txt
((monHttp.body.$.items[0].name)), ((monHttp.body.$.items[1].name)), ...
```
