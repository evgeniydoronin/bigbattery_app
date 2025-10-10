# Git Rules - СТРОГО ОБЯЗАТЕЛЬНЫ

**⚠️ КРИТИЧЕСКОЕ ПРАВИЛО ⚠️**

---

## ❌ НИКОГДА НЕ ДОБАВЛЯТЬ В КОММИТЫ:

### ❌ ЗАПРЕЩЕНО:

```
🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

### ❌ НЕТ COPYRIGHTS!
### ❌ НЕТ "Generated with"!
### ❌ НЕТ "Co-Authored-By"!

**Это правило НЕ обсуждается. НИКОГДА не добавляй эти строки.**

---

## ✅ Правильный формат commit message

### Структура:

```
<type>: <short description>

Root Causes:
1. <root cause 1>
2. <root cause 2>
...

Changes:

1. <change 1>
   - Detail 1
   - Detail 2

2. <change 2>
   - Detail 1
   - Detail 2

...

Result:
- ✅ <positive result 1>
- ✅ <positive result 2>
- ✅ <positive result 3>

Files Modified:
- <file 1>
- <file 2>

Files Added:
- <file 1>
- <file 2>
```

### Types:

- `fix:` - Bug fix
- `feat:` - New feature
- `refactor:` - Code refactoring
- `docs:` - Documentation changes
- `test:` - Adding tests
- `chore:` - Maintenance tasks

---

## ✅ Пример ПРАВИЛЬНОГО коммита:

```
fix: Fix duplicate values, reconnection, and threading bugs

Root Causes:
1. Battery returns error code 0x01 when trying to set duplicate values
2. Stale cachedDeviceUUID preventing reconnection
3. RxSwift callbacks executing on background thread causing crashes

Changes:

1. Duplicate Value Detection (SettingsViewController.swift):
   - Check current values before sending commands
   - Skip unchanged values with logging
   - Prevents battery error 0x01 responses

2. Reconnection Fix (ZetaraManager.swift):
   - Reset cachedDeviceUUID to nil
   - Clear all Bluetooth characteristics
   - Enables clean reconnection after battery restart

3. Threading Bug Fix (SettingsViewController.swift):
   - Added .observe(on: MainScheduler.instance) before .subscribe()
   - Ensures UI updates execute on main thread

Result:
- ✅ No more duplicate value errors
- ✅ Clean reconnection after battery restart
- ✅ No threading crashes when saving settings
- ✅ Better error messages for users

Files Modified:
- BatteryMonitorBL/SettingsViewController.swift
- Zetara/Sources/ZetaraManager.swift
- BatteryMonitorBL/ConnectivityViewController.swift

Files Added:
- docs/manufacturer-documentation-request.md
```

---

## ❌ Пример НЕПРАВИЛЬНОГО коммита:

```
fix: Fix duplicate values

Changes:
- Fixed some stuff

🤖 Generated with [Claude Code](https://claude.com/claude-code)   ← ❌ ЗАПРЕЩЕНО!

Co-Authored-By: Claude <noreply@anthropic.com>                    ← ❌ ЗАПРЕЩЕНО!
```

**Проблемы:**
1. ❌ Есть копирайты
2. ❌ Нет Root Causes
3. ❌ Нет детальных Changes
4. ❌ Нет Result
5. ❌ Нет Files Modified/Added

---

## Checklist перед коммитом

### ОБЯЗАТЕЛЬНО проверить:

- [ ] ❌ **НЕТ "Generated with Claude Code"**
- [ ] ❌ **НЕТ "Co-Authored-By: Claude"**
- [ ] ❌ **НЕТ emoji 🤖 в конце сообщения**
- [ ] ✅ Есть раздел "Root Causes"
- [ ] ✅ Есть раздел "Changes" с деталями
- [ ] ✅ Есть раздел "Result" с ✅
- [ ] ✅ Есть "Files Modified" и "Files Added"
- [ ] ✅ Описание понятное и полное

---

## Команды Git

### Создание коммита:

```bash
# 1. Добавить файлы в staging
git add <file1> <file2> ...

# 2. Создать коммит (используй heredoc для многострочного сообщения)
git commit -m "$(cat <<'EOF'
fix: Short description

Root Causes:
1. ...

Changes:
1. ...

Result:
- ✅ ...

Files Modified:
- ...
EOF
)"

# 3. Push в remote
git push
```

### Если ошибся и добавил копирайты:

```bash
# Отменить последний коммит (изменения остаются)
git reset HEAD~1

# Исправить commit message
git commit -m "..." # БЕЗ КОПИРАЙТОВ!

# Force push (если уже pushил)
git push --force
```

---

## Частые ошибки

### Ошибка 1: Автоматическое добавление копирайтов

**Проблема:** Claude автоматически добавляет "Generated with Claude Code"

**Решение:**
1. ВСЕГДА проверяй commit message перед `git commit`
2. Если увидел копирайты → НЕ коммить!
3. Убери копирайты вручную
4. Коммить только ЧИСТОЕ сообщение

### Ошибка 2: Забыл про git-rules.md

**Проблема:** Не прочитал git-rules.md перед коммитом

**Решение:**
1. Добавь в TODO: "Прочитать git-rules.md" ПЕРЕД коммитом
2. В START-HERE.md есть напоминание в каждом шаге

### Ошибка 3: Слишком короткое сообщение

**Проблема:** Commit message без Root Causes, Changes, Result

**Решение:**
1. Используй шаблон из этого документа
2. Заполни ВСЕ секции
3. Чем подробнее - тем лучше

---

## Почему NO COPYRIGHTS?

### Причины:

1. **Профессионализм** - коммиты должны быть чистыми и professional
2. **История проекта** - git history = техническая документация
3. **Соглашение команды** - единый стандарт для всех
4. **Юридические причины** - авторство определяется git author, не текстом

### Что использовать вместо?

**Git author автоматически сохраняется:**

```bash
git config user.name "Your Name"
git config user.email "your@email.com"
```

Каждый коммит содержит:
- Author name
- Author email
- Commit date
- Commit hash

**Этого достаточно для отслеживания авторства!**

---

## Summary

### 3 Главных правила:

1. ❌ **NO COPYRIGHTS** (Generated with, Co-Authored-By)
2. ✅ **Полная структура** (Root Causes, Changes, Result, Files)
3. ✅ **Проверка перед коммитом** (checklist)

### Перед КАЖДЫМ коммитом спроси себя:

```
1. Прочитал ли я git-rules.md?
2. Есть ли копирайты в сообщении?
3. Есть ли Root Causes?
4. Есть ли детальные Changes?
5. Есть ли Result с ✅?
6. Перечислены ли все файлы?
```

**Если на ВСЕ вопросы "ДА" (кроме #2 - должно быть "НЕТ") → коммит ГОТОВ!**

---

**Последнее обновление:** 2025-10-10
