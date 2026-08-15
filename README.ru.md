# workflow

[🇬🇧 English](./README.md) | 🇷🇺 Русский

Эталонная/стартовая конфигурация для корпоративной, spec-driven разработки
в multirepo-приложении, с использованием [OpenSpec](https://github.com/Fission-AI/OpenSpec).

**Если вы frontend/backend/и т.д. разработчик**, этот репозиторий вам,
скорее всего, вообще не нужен — клонируйте напрямую свой репозиторий
приложения и смотрите его `README.md` + [`AGENTS.md`](./AGENTS.md), раздел
«Two roles» («Две роли»), чтобы понять свой день ото дня. Этот репозиторий
нужен для составления предложений (proposals), затрагивающих несколько
репозиториев, и для фиксации того, какая комбинация версий репозиториев
поставляется вместе (deployment pinning).

## Быстрый старт (этот репозиторий)

```bash
git clone --recurse-submodules <this-repo-url> workflow
cd workflow
make init      # обновление сабмодулей + локальная регистрация общего store "specifications"
make doctor    # проверка связки OpenSpec root/store
make sync      # подтянуть последние shared specifications; отчёт по сабмодулям
```

## Структура

```
specifications/   общий store спецификаций (сабмодуль) — только сквозные контракты
src/
  common/          общие контракты/типы, публикуются как пакет
  frontend/        заглушка — реального remote пока нет
  backend/         заглушка
  gitops_frontend/ заглушка
  gitops_backend/  заглушка
  nginx/           заглушка
scripts/
  setup-openspec.sh  локально регистрирует store specifications (идемпотентно)
  add-repo.sh        превращает заглушку src/<name> в настоящий сабмодуль
  sync.sh            подтягивает последние specifications + отчёт по сабмодулям
```

Превратить заглушку в реальный репозиторий, когда он появится:

```bash
scripts/add-repo.sh frontend git@github.com:your-org/frontend.git
```

## Документация

Пошаговые руководства по ролям — от задачи в Jira до продакшена, включая то,
как использовать OpenSpec и ИИ-инструменты в повседневной работе:

- [Workflow разработчика](./docs/developer-workflow.ru.md) ([English](./docs/developer-workflow.md)) —
  для frontend/backend/common/gitops/nginx инженеров (Mode B).
- [Workflow аналитики / архитектуры](./docs/analytics-workflow.ru.md) ([English](./docs/analytics-workflow.md)) —
  для аналитиков и архитекторов, составляющих межрепозиторные предложения (Mode A).

## Полная модель

Полное описание архитектуры — в [`AGENTS.md`](./AGENTS.md) (на английском):
три вида корня OpenSpec, разделение ролей аналитика/разработчик, правило о
том, где создаётся изменение (локальный репозиторий vs. общий store),
**какие артефакты пишет аналитика, а какие планирует разработчик**
(`AGENTS.md`, раздел «Propose vs. plan: who writes what» — аналитика
останавливается после `proposal.md` + `specs/`; `design.md` + `tasks.md`
пишет разработчик-исполнитель, а не аналитика), соглашение о шлюзовании
`tasks.md` по контракту, и как frontend/backend реализуют изменения
параллельно, не подключая друг друга сабмодулями.
