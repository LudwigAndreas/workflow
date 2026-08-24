# workflow

[🇬🇧 English](./README.md) | 🇷🇺 Русский

Эталонная/стартовая конфигурация для корпоративной спецификационно-ориентированной
разработки (SDD) в мультирепозиторном приложении на базе
[OpenSpec](https://github.com/Fission-AI/OpenSpec), связанная с доской Jira по
Agile/Scrum.

Рассчитана на **Bitbucket Data Center + Jenkins + Argo CD**. Пайплайны Jenkins
лежат здесь общей библиотекой (`vars/`); в каждом репозитории — `Jenkinsfile`
на пять строк.

**Начните отсюда: [`docs/pipeline.ru.md`](./docs/pipeline.ru.md)** — одна
диаграмма, шесть ролей, одиннадцать шлюзов в трёх фазах и ответ на вопрос «где
источник истины».

Он покрывает всю петлю, а не только спецификации: намерение → proposal →
утверждение → код → **версия, тег, образ, выкатка, Fix Version в Jira,
комментарий о выкатке, промоушен, архивация**. Всё начиная с влития
автоматизировано; последнее действие разработчика по story — влитие PR.

**Если вы разработчик фронтенда/бэкенда и т. п.**, этот репозиторий вам скорее
всего не нужен вовсе — клонируйте свой репозиторий приложения и читайте
[`docs/roles/developer.ru.md`](./docs/roles/developer.ru.md). Этот репозиторий
нужен для написания proposal, охватывающих несколько репозиториев, и для
фиксации того, какая комбинация версий выкатывается вместе.

## Модель в девяти строках

```
1 Epic  = N stories                      фича, слишком большая для одной дельты
1 Story = 1 изменение OpenSpec           = 1 дельта   <- метка SDD + change-id
1 Task  = 1 репозиторий = 1 ветка = 1 PR = 1 секция tasks.md
```

Task режет *поставку*, а не *спецификацию*. Лекарство от слишком большой story —
Epic, а не дополнительные task'и. Ветки называются `PROJ-123-slug` или
`PROJ-123/PROJ-124-slug`, когда веткой владеет task — так ветка связывается и с
помеченной Story, и с Task.

## Быстрый старт (этот репозиторий)

```bash
git clone --recurse-submodules <this-repo-url> workflow
cd workflow
make init      # обновление сабмодулей + регистрация хранилища "specifications"
make doctor    # проверка связи корня OpenSpec и хранилища
make sync      # подтянуть свежие общие спецификации
make check     # проходит ли текущий чекаут метрику SDD?
```

## Документация

В первый раз читайте в этом порядке.

| | |
|---|---|
| [Пайплайн](./docs/pipeline.ru.md) ([EN](./docs/pipeline.md)) | **начните здесь** — шлюзы, владельцы, карта источников истины |
| [Типы работ](./docs/work-types.ru.md) ([EN](./docs/work-types.md)) | полоса для *любого* вида работы: баг, хотфикс, техдолг, рутина, спайк |
| [Scrum-слой](./docs/scrum.ru.md) ([EN](./docs/scrum.md)) | двухтрековые спринты, две доски, DoR/DoD, ёмкость, церемонии |
| [Релиз](./docs/release.ru.md) ([EN](./docs/release.md)) | версии, теги, образы, промоушен, обратная связь в Jira |
| [Автоматизация](./docs/automation.ru.md) ([EN](./docs/automation.md)) | каждый триггер → действие, все секреты и что остаётся людям |
| [Руководство по сборке](./docs/build-guide.ru.md) ([EN](./docs/build-guide.md)) | **как всё это построить**, девять фаз по шагам |
| [Связка Jira ↔ SDD](./docs/jira-sdd-mapping.ru.md) ([EN](./docs/jira-sdd-mapping.md)) | Epic/Story/Task ↔ OpenSpec, именование веток, метрика |

Роли — читайте свою, пролистайте две соседние:

| Роль | | Вы владеете |
|---|---|---|
| Тимлид | [RU](./docs/roles/team-lead.ru.md) · [EN](./docs/roles/team-lead.md) | размером story, метками, объёмом спринта, метрикой |
| Техлид | [RU](./docs/roles/tech-lead.ru.md) · [EN](./docs/roles/tech-lead.md) | утверждением контрактов, техподходом, промоушеном в прод |
| Аналитик | [RU](./docs/roles/analytics.ru.md) · [EN](./docs/roles/analytics.md) | `proposal.md` + `specs/*.md` |
| Разработчик | [RU](./docs/roles/developer.ru.md) · [EN](./docs/roles/developer.md) | `design.md` + `tasks.md` + кодом |
| Тестировщик | [RU](./docs/roles/tester.ru.md) · [EN](./docs/roles/tester.md) | качеством сценариев, проверкой |
| DevOps | [RU](./docs/roles/devops.ru.md) · [EN](./docs/roles/devops.md) | пайплайном, промоушеном, откатом |

[`AGENTS.md`](./AGENTS.md) — полная архитектурная справка за всем этим.

## Структура

```
docs/               пайплайн, типы работ, scrum, релиз, автоматизация, роли
specifications/     общее хранилище спеков (сабмодуль) — только сквозные контракты
src/
  common/           общие контракты/типы, публикуется пакетом
  frontend/         заглушка — реальный remote ещё не подключён
  backend/          заглушка
  gitops_frontend/  заглушка
  gitops_backend/   заглушка
  nginx/            заглушка
scripts/
  setup-openspec.sh  регистрирует хранилище specifications локально (идемпотентно)
  add-repo.sh        превращает заглушку src/<name> в настоящий сабмодуль
  sync.sh            подтягивает свежие specifications + статус сабмодулей
  check-sdd.sh       проверяет метрику «story followed SDD»
  release-version.sh следующий semver из conventional commits; теги; notes
  jira-release.sh    создаёт версию Jira, проставляет Fix Version
  jira-deploy.sh     комментарий о выкатке + поле Deployed Environments
  promote.sh         копирует digest образа между оверлеями Argo CD
vars/                общая библиотека Jenkins — сами пайплайны
  sddRelease.groovy  шлюз 7 — версия, тег, образ, Fix Version
  sddPromote.groovy  шлюз 10 — запись оверлея, PR в Bitbucket для прода
  sddObserve.groovy  шлюз 8 — здоровье Argo, обратная связь в Jira, откат
  sddPrChecks.groovy conventional-заголовки PR, имена веток, выживание ключей
examples/            короткие Jenkinsfile, которые копирует каждый репозиторий
```

Превратить заглушку в сабмодуль, когда реальный репозиторий появился:

```bash
scripts/add-repo.sh frontend ssh://git@bitbucket.acme.com/plat/frontend.git
```

## Метрика SDD

Story считается «followed SDD», когда это Story с меткой `SDD`, связанная с
изменением OpenSpec, у которой секции `tasks.md` несут ключи Jira, ветки
соответствуют шаблону — и **чья дельта спецификации была влита до первого
коммита в любой ветке**. Последнее условие и отличает *followed SDD* от
*labelled SDD*.

```bash
make check                                   # локальный корень
make check-shared                            # общее хранилище
JIRA_URL=... JIRA_TOKEN=... make check       # плюс проверка метки через Jira
```

## Релизная петля

Влейте PR — больше от вас ничего не требуется:

```
squash-влитие в main в Bitbucket
  -> Jenkins sddRelease
  -> версия из conventional commits            backend 1.4.2 -> 1.5.0
  -> аннотированный тег + неизменяемый образ   backend-1.5.0
  -> создана версия Jira «backend 1.5.0», Fix Version проставлен на PROJ-123
  -> обновлён оверлей dev в репозитории Argo CD, Argo синхронизируется
  -> 🚀 «Выкачено в dev — backend 1.5.0» в комментарии тикета
  -> story роллапится в Verifying, тестировщик уведомлён
  -> тестировщик прошёл -> staging автоматически
  -> прод: один pull request в Bitbucket, одно подтверждение, одно влитие
  -> версия Jira помечена Released, story Done
```

Подробности в [release.ru.md](./docs/release.ru.md), связывание в
[automation.ru.md](./docs/automation.ru.md), порядок сборки в
[build-guide.ru.md](./docs/build-guide.ru.md).

```bash
scripts/release-version.sh --service backend --json    # что бы зарелизилось?
scripts/jira-release.sh --service backend --version 1.5.0 --dry-run
```

## Команды для ИИ

`/sdd:intake` · `/sdd:plan` · `/sdd:qa-review` · `/sdd:gate` — обёртки по ролям,
которые следят за правилом размера, связкой с Jira и соглашением о секциях. Они
надстроены над «сырыми» командами OpenSpec (`/opsx:propose`, `/opsx:apply`,
`/opsx:archive`, `/opsx:sync`, `/opsx:explore`, `/opsx:update`).
