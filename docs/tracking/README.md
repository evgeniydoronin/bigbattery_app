# Build Tracking System

Система отслеживания билдов, фич, регрессий и стабильных версий для быстрого поиска информации о состоянии проекта.

## 📁 Файлы в этой папке

### 🏗️ [BUILD-TRACKING.md](BUILD-TRACKING.md)
**Назначение:** Feature × Build матрица - что работает в каждом билде

**Когда использовать:**
- Хочешь узнать "что работает в Build 36?"
- Нужно увидеть полную картину статуса всех фич в конкретном билде
- Хочешь сравнить два билда (что изменилось между Build 35 и 36?)

**Содержит:**
- Секция для каждого билда (Build 29-36+)
- Feature status table (Connection, Settings, Crashes, BMS data)
- Git commit hash для каждого билда
- Ссылки на test logs
- Known issues

**Формат:**
```markdown
## Build 36 (2025-11-07) - CURRENT
| Feature | Status | Evidence |
|---------|--------|----------|
| Settings Display | ✅ WORKS | THREAD-001, Build 36 SUCCESS |
...
```

---

### 🎯 [STABLE-BUILDS.md](STABLE-BUILDS.md)
**Назначение:** Quick reference - последний стабильный билд для каждой фичи

**Когда использовать:**
- "Какой последний билд без crashes?" → Build 35+
- "Когда Settings display последний раз работал?" → Build 36
- Нужно откатиться на working version
- Хочешь знать текущий recommended build

**Содержит:**
- Last Known Good table (фича → билд → коммит)
- Current Recommended Build с обоснованием
- Rollback scenarios (когда и на что откатываться)
- Evidence links (логи, THREAD-001)

**Формат:**
```markdown
| Feature | Last Known Good Build | Commit | Date |
|---------|----------------------|--------|------|
| Settings Display | Build 36 ✅ | c5db5fe | 2025-11-07 |
```

---

### 📈 [REGRESSION-TIMELINE.md](REGRESSION-TIMELINE.md)
**Назначение:** Хронология break/fix - когда что сломалось и когда починилось

**Когда использовать:**
- "Когда Settings display сломался?" → Build 35
- "Что сломалось между Build 31 и Build 32?" → Error 4 regression
- Хочешь увидеть эволюцию проблемы
- Нужно понять lessons learned из прошлых регрессий

**Содержит:**
- Обратная хронология (Build 36 → Build 29)
- Каждый break/fix event с деталями:
  - What broke/fixed
  - Root cause
  - Impact на пользователя
  - В каком билде починилось
  - Commit hash
  - Thread reference

**Формат:**
```markdown
## 2025-11-07: Build 36 - Settings Display RESOLVED ✅
**Root Cause:** disposeBag recreation destroyed subscriptions
**Commit:** c5db5fe
**Thread:** THREAD-001 Attempt #6
```

---

## 🏷️ Git Tags System

Каждый билд имеет git tag для быстрой навигации:

```bash
# Показать коммит конкретного билда
git show build-36

# Сравнить два билда
git diff build-35..build-36

# Посмотреть историю между билдами
git log build-34..build-36

# Откатиться на конкретный билд
git checkout build-31
```

**Доступные tags:**
- `build-29` → Build 29 (Attempt #2 - Proactive monitoring)
- `build-30` → Build 30 (Pre-flight abort - CATASTROPHIC FAILURE)
- `build-31` → Build 31 (Scan list validation - SUCCESS)
- `build-32` → Build 32 (UITableView crashes fixed)
- `build-33` → Build 33 (Fresh peripheral in connect - FAILED)
- `build-34` → Build 34 (Launch-time fresh peripheral - SUCCESS but crash)
- `build-35` → Build 35 (Guard during disconnect - Crash fixed)
- `build-36` → Build 36 (Fix Settings subscriptions - SUCCESS VERIFIED)

---

## 🔄 Обновление при новых билдах

При создании нового билда (например, Build 37):

### 1. Создать git tag (1 мин)
```bash
git tag -a build-37 <commit-hash> -m "Build 37: <краткое описание>"
git push origin --tags
```

### 2. Обновить BUILD-TRACKING.md (5 мин)
```markdown
## Build 37 (2025-11-10) - CURRENT
| Feature | Status | Evidence |
|---------|--------|----------|
| Connection Stability | ✅ WORKS | Build 37 fix |
| ... | ... | ... |

**Git Commit:** <hash>
**Test Logs:** bigbattery_logs_20251110_*.json
**Known Issues:** None
```

### 3. Обновить STABLE-BUILDS.md (2 мин)
Если что-то починилось - обновить Last Known Good table и Current Recommended Build.

### 4. Добавить в REGRESSION-TIMELINE.md (3 мин)
Если был break или fix - добавить entry в начало timeline.

**TOTAL: ~10 минут на update**

---

## 📚 Связь с другой документацией

### Issue Threads
- **THREAD-001** (issue-threads/THREAD-001_invalid-device-reconnection.md)
  - Глубокое исследование проблемы reconnection
  - 7 attempts (Build 29-36)
  - Root cause evolution, expected vs reality
  - **Когда использовать:** Нужны технические детали, root cause analysis

### Fix History
- **fix-history/** - одноразовые fixes
  - Логи тестирования
  - Разовые проблемы решенные за 1 attempt

### Отличия:
| Файл | Назначение | Когда использовать |
|------|-----------|-------------------|
| **THREAD-001** | Deep dive одной проблемы | Нужны технические детали, root cause |
| **BUILD-TRACKING** | Overview всех фич по билдам | Хочу видеть big picture конкретного билда |
| **STABLE-BUILDS** | Quick reference stab ильных билдов | Хочу откатиться или узнать recommended build |
| **REGRESSION-TIMELINE** | История break/fix | Хочу понять когда что сломалось |

---

## 💡 Примеры использования

### Сценарий 1: "В каком билде Settings последний раз работал?"
1. Открыть **STABLE-BUILDS.md**
2. Найти "Settings Display" в таблице
3. Ответ: Build 36 ✅ (c5db5fe, 2025-11-07)

### Сценарий 2: "Что сломалось между Build 34 и Build 35?"
1. Открыть **REGRESSION-TIMELINE.md**
2. Найти "Build 35" section
3. Ответ: Settings Display регрессия (показывает "--")

### Сценарий 3: "Какие фичи работают в Build 36?"
1. Открыть **BUILD-TRACKING.md**
2. Найти "Build 36" section
3. Посмотреть Feature status table

### Сценарий 4: "Хочу откатиться на последний билд без Settings проблем"
1. Открыть **STABLE-BUILDS.md** → Current Recommended Build
2. Или Rollback Scenarios → "If Settings Display Breaks"
3. `git checkout build-36`

### Сценарий 5: "Почему Settings сломался в Build 35?"
1. Открыть **REGRESSION-TIMELINE.md** → "Build 35" section для краткого overview
2. Для деталей открыть **THREAD-001** → "Build 35" section
3. Полный root cause: `disposeBag = DisposeBag()` в `viewWillDisappear`

---

## 🎯 Цель tracking системы

**Проблема:** Раньше чтобы понять "что работает в Build 36" надо было:
- Читать 1369 строк THREAD-001
- Вручную искать в git log
- Не было quick reference для rollback

**Решение:** Tracking система дает:
- ✅ Quick lookup - ответ за 30 секунд
- ✅ Git tags - мгновенный доступ к любому билду
- ✅ Feature matrix - что работает в каждом билде
- ✅ Regression history - когда что сломалось
- ✅ Rollback scenarios - как откатиться на working version

**Результат:**
- Быстрое принятие решений
- Легкий rollback при регрессиях
- Ясная картина стабильности проекта
- Сохранение institutional knowledge

---

## 📞 Вопросы?

Если не понятно как использовать tracking систему - смотри [START-HERE.md](../START-HERE.md) раздел "Quick Reference".
