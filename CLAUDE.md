# Правила работы Claude в этом проекте

## Коммиты в Git

### ЗАПРЕЩЕНО
- **НЕ добавлять копирайты Claude** (`Generated with Claude Code`, `Co-Authored-By: Claude`) в коммиты
- НЕ коммитить без предварительного согласования

### ОБЯЗАТЕЛЬНО
1. **Перед коммитом** выполнить параллельно:
   ```bash
   git status
   git diff --staged  # или git diff
   git log -5 --oneline
   ```

2. **Проанализировать изменения:**
   - Какие файлы изменены и зачем
   - Тип изменения (fix, feat, docs, refactor и т.д.)
   - Суть изменения в 1-2 предложениях

3. **Показать draft commit message** пользователю для одобрения

4. **Только после одобрения** делать коммит

### Стиль коммитов в этом репозитории
Коммиты должны быть детальными и структурированными:

**Формат:**
```
fix: Краткое описание (Build N)

Root Cause:
[Объяснение причины проблемы]

Solution:
[Описание решения]

Changes:
- Файл1:
  * Изменение 1 (lines X-Y)
  * Изменение 2
- Файл2:
  * Изменение

Expected Result:
- Ожидаемый результат 1
- Ожидаемый результат 2

Build N Status: Ready for testing
```

**Примеры заголовков:**
```
fix: Add launch-time fresh peripheral retrieval to prevent stale characteristics (Build 34)
fix: Eliminate error 4 by retrieving fresh peripheral instance (Build 33)
fix: Fix UITableView crashes in Build 31 (Build 32)
docs: Update THREAD-001 with Build 30 failure and Build 31 fix
```

**Важно:**
- Детальное описание с Root Cause, Solution, Changes, Expected Result
- Указывать номера строк для изменений в коде
- Описывать все измененные файлы
- Без копирайтов Claude!

## Работа с кодом

### Swift
- Следовать существующему стилю кодирования
- Комментарии на английском
- Использовать guard statements для ранних выходов
- RxSwift: `.value()` это метод, не свойство - вызывать с `()`

### Документация
- Обновлять THREAD-001 при каждом изменении
- Добавлять логи в `docs/fix-history/logs/`
- Документировать решения и их причины

## Build Versioning
- Каждый значимый фикс = новый Build номер
- Обновлять `CURRENT_PROJECT_VERSION` в `project.pbxproj`
- Документировать в THREAD-001

## Тестирование
- Проверять компиляцию после изменений
- Описывать expected results для каждого билда
- Ждать результатов тестирования от Joshua
