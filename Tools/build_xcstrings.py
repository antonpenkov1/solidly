#!/usr/bin/env python3
"""Builds Tummi/Localizable.xcstrings from the English source strings plus the Russian map below.

Run after `xcodebuild -exportLocalizations` has produced a fresh key list:

    xcodebuild -project Tummi.xcodeproj -scheme Tummi \
        -exportLocalizations -localizationPath /tmp/tummi_loc -exportLanguage ru
    python3 Tools/build_xcstrings.py /tmp/tummi_loc/ru.xcloc/Localized\\ Contents/ru.xliff

Keys with no Russian entry are written untranslated ("new"), so a build after adding UI copy
tells you exactly what is missing instead of silently shipping English.

Russian plurals: single-argument count strings get one/few/many/other variations. Strings with
more than one argument are phrased so the number never changes the surrounding word — the
`substitutions` form the catalogue needs for those is not worth the fragility here.
"""
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

RU = {
    # --- Tabs, screens, chrome -------------------------------------------------
    "Today": "Сегодня",
    "Log": "Дневник",
    "Foods": "Продукты",
    "Plan": "План",
    "Growth": "Рост",
    "Settings": "Настройки",
    "Sources": "Источники",
    "Yesterday": "Вчера",
    "Recent": "Недавнее",
    "History": "История",
    "Timeline": "Хронология",
    "Coming up": "Впереди",
    "Today so far": "Сегодня уже",
    "guidance range": "ориентир",
    "Last 30 days": "Последние 30 дней",

    # --- Buttons and generic actions -------------------------------------------
    "Save": "Сохранить",
    "Cancel": "Отмена",
    "Done": "Готово",
    "Edit": "Изменить",
    "Delete": "Удалить",
    "Continue": "Далее",
    "Get started": "Начать",
    "Optional": "Необязательно",
    "Search foods": "Поиск продуктов",
    "Try another search or filter.": "Попробуйте другой запрос или фильтр.",
    "Nothing here": "Здесь пусто",

    # --- Onboarding ------------------------------------------------------------
    "Feeding your baby, with the reasoning attached.":
        "Кормление ребёнка — вместе с обоснованием.",
    "Every recommendation in this app names the guideline or trial it comes from, so you can read it yourself — or take it to your paediatrician and disagree with it.":
        "Каждая рекомендация здесь названа своим источником — гайдом или исследованием. Вы можете прочитать его сами или принести своему педиатру и не согласиться.",
    "WHO, ESPGHAN, AAP, NIAID and the trials behind them":
        "ВОЗ, ESPGHAN, AAP, NIAID и исследования, на которых они стоят",
    "Track grams, millilitres, growth and allergen exposures":
        "Считайте граммы, миллилитры, рост и контакты с аллергенами",
    "Replace any number with the one your doctor gave you":
        "Замените любую цифру на ту, что дал ваш врач",
    "Everything stays on this device": "Всё остаётся на этом устройстве",
    "About your baby": "О ребёнке",
    "Name": "Имя",
    "Date of birth": "Дата рождения",
    "Sex": "Пол",
    "Girl": "Девочка",
    "Boy": "Мальчик",
    "Growth percentiles are read against different WHO curves for girls and boys.":
        "Перцентили роста считаются по разным кривым ВОЗ для девочек и мальчиков.",
    "Born before 37 weeks": "Родился раньше 37 недель",
    "%lld weeks at birth": {"one": "%lld неделя при рождении", "few": "%lld недели при рождении",
                            "many": "%lld недель при рождении", "other": "%lld недель при рождении"},
    "Tummi will use corrected age for feeding milestones and growth charts, which is how they are meant to be read for preterm babies.":
        "Tummi будет использовать скорректированный возраст для этапов прикорма и кривых роста — именно так их и положено читать для недоношенных детей.",
    "Units": "Единицы",
    "Metric": "Метрические",
    "Imperial": "Имперские",
    "Before you start": "Прежде чем начать",
    "Tummi is not a doctor": "Tummi — не врач",
    "It summarises published guidance. It does not diagnose anything, and it cannot see your baby. Your paediatrician's advice takes priority over everything shown here — and you can enter their numbers so the app follows them instead.":
        "Приложение пересказывает опубликованные рекомендации. Оно ничего не диагностирует и не видит вашего ребёнка. Слово вашего педиатра важнее всего, что здесь показано, — и вы можете внести его цифры, чтобы приложение следовало им.",
    "Amounts are ranges, not targets": "Количество — это диапазон, а не норма",
    "Babies vary enormously day to day. Use the numbers to spot a trend over weeks, never to push a baby to finish a portion.":
        "Дети сильно меняются день ото дня. Цифры нужны, чтобы видеть тенденцию за недели, а не чтобы заставлять ребёнка доедать порцию.",
    "When to call someone": "Когда звонить",
    "Trouble breathing, a swollen face or lips, repeated vomiting after a food, blood in stool, or a baby who has stopped feeding — contact emergency services or your doctor, not an app.":
        "Затруднённое дыхание, отёк лица или губ, многократная рвота после продукта, кровь в стуле или ребёнок перестал есть — звоните в скорую или врачу, а не открывайте приложение.",
    "Your data stays here": "Данные остаются здесь",
    "Everything is stored on this device. Tummi has no account, no server and no analytics.":
        "Всё хранится на этом устройстве. У Tummi нет аккаунта, сервера и аналитики.",
    "I understand — start tracking": "Понятно — начать",
    "That date is in the future.": "Эта дата в будущем.",
    "Baby": "Малыш",

    # --- Today -----------------------------------------------------------------
    "No child yet": "Ребёнок ещё не добавлен",
    "Add a baby in Settings to start tracking.": "Добавьте ребёнка в настройках, чтобы начать.",
    "Breast": "Грудь",
    "Bottle": "Бутылочка",
    "Food": "Еда",
    "Water": "Вода",
    "Nappy": "Подгузник",
    "Milk": "Молоко",
    "Milk feeds": "Кормлений молоком",
    "Meals": "Приёмы пищи",
    "Food eaten": "Съедено",
    "Nothing logged today yet.": "Сегодня пока ничего не записано.",
    "Breastfeed": "Грудное кормление",
    "Formula": "Смесь",
    "Expressed milk": "Сцеженное молоко",
    "Meal": "Приём пищи",
    "Supplement": "Добавка",
    "Sleeping for %@": "Спит уже %@",
    "Sleeping since %@": "Спит с %@",
    "%@ corrected": "%@ скорр.",
    "Following your paediatrician's numbers.": "Следуем цифрам вашего педиатра.",
    "Following your paediatrician's numbers — %@.": "Следуем цифрам вашего педиатра — %@.",
    "Not tried yet: %@": "Ещё не пробовали: %@",
    # Colon rather than a preposition: allergen names arrive from the data layer in the
    # nominative, and "Продолжайте с арахис" would need a case the data cannot supply.
    "Keep going with %@": "Продолжайте давать: %@",
    "Introduce one new allergen at a time, at home and earlier in the day, so you have hours of daylight to watch.":
        "Вводите по одному новому аллергену за раз, дома и в первой половине дня, чтобы впереди был световой день для наблюдения.",
    "%lld exposures so far. The prevention trials relied on eating it regularly — roughly twice a week — not on a single taste.":
        {"one": "Пока %lld контакт. В исследованиях по профилактике продукт ели регулярно — примерно дважды в неделю, — а не пробовали один раз.",
         "few": "Пока %lld контакта. В исследованиях по профилактике продукт ели регулярно — примерно дважды в неделю, — а не пробовали один раз.",
         "many": "Пока %lld контактов. В исследованиях по профилактике продукт ели регулярно — примерно дважды в неделю, — а не пробовали один раз.",
         "other": "Пока %lld контактов. В исследованиях по профилактике продукт ели регулярно — примерно дважды в неделю, — а не пробовали один раз."},
    "First time trying %@ today.": "Сегодня впервые пробуем: %@.",
    "%1$lld new foods today: %2$@.": "Новых продуктов сегодня — %1$lld: %2$@.",
    "in a few weeks": "через пару недель",
    "at %lld months": {"one": "в %lld месяц", "few": "в %lld месяца",
                       "many": "в %lld месяцев", "other": "в %lld месяцев"},

    # --- Log -------------------------------------------------------------------
    "Nothing logged yet": "Записей пока нет",
    "Tap the plus to record a feed, a nappy or a nap.":
        "Нажмите плюс, чтобы записать кормление, подгузник или сон.",
    "Start a nap": "Начать сон",
    "Wake up": "Проснулся",
    "Sleep": "Сон",
    "Sleeping": "Спит",
    "Wet nappy": "Мокрый подгузник",
    "Dirty nappy": "Грязный подгузник",
    "Wet and dirty": "Мокрый и грязный",
    "Dry nappy": "Сухой подгузник",
    "Wet": "Мокрый",
    "Dirty": "Грязный",
    "Both": "Оба",
    "Dry": "Сухой",
    "When": "Когда",
    "Note": "Заметка",
    "Six or more wet nappies a day is the usual sign that a young baby is getting enough milk.":
        "Шесть и больше мокрых подгузников в сутки — обычный признак того, что маленькому ребёнку хватает молока.",
    "%lld milk feeds": {"one": "%lld кормление молоком", "few": "%lld кормления молоком",
                        "many": "%lld кормлений молоком", "other": "%lld кормлений молоком"},
    "%1$lld meals · %2$@": "приёмов: %1$lld · %2$@",

    # --- Log entry sheet -------------------------------------------------------
    "Side": "Грудь",
    "Left": "Левая",
    "Right": "Правая",
    "left": "левая",
    "right": "правая",
    "both": "обе",
    "Duration": "Длительность",
    "What's in it": "Что внутри",
    "Amount": "Объём",
    "Amount eaten": "Сколько съедено",
    "How it went": "Как прошло",
    "Loved it": "В восторге",
    "Ate it": "Съел",
    "Tasted": "Попробовал",
    "Refused": "Отказался",
    "loved it": "в восторге",
    "ate it": "съел",
    "tasted": "попробовал",
    "refused": "отказался",
    "Refusing is normal — it can take 10–15 offers of a new food before a child accepts it.":
        "Отказ — это нормально: иногда новый продукт нужно предложить 10–15 раз, прежде чем ребёнок его примет.",
    "Any reaction": "Была реакция",
    "None": "Нет",
    "Mild": "Лёгкая",
    "Notable": "Заметная",
    "Trouble breathing, swelling of the face or lips, or repeated vomiting needs emergency care now — not a log entry.":
        "Затруднённое дыхание, отёк лица или губ, многократная рвота — это повод вызвать скорую прямо сейчас, а не сделать запись в дневнике.",
    "Choose foods": "Выберите продукты",
    "In this meal": "В этом приёме",
    "Delete entry": "Удалить запись",

    # --- Foods -----------------------------------------------------------------
    "%1$lld of %2$lld foods tried": "Попробовано продуктов: %1$lld из %2$lld",
    "Allergen exposure": "Контакт с аллергенами",
    "Regular repeat exposure is what the prevention trials tested — roughly twice a week, not one taste.":
        "В исследованиях по профилактике проверяли именно регулярное повторное употребление — примерно дважды в неделю, а не одну пробу.",
    "not started": "не начинали",
    "%lld×, keep going": "%lld×, продолжайте",
    "%lld×, regular": "%lld×, регулярно",
    "reaction logged": "была реакция",
    "tried once": "1 раз",
    "%lld times": "%lld ×",
    "Cut safely": "Резать правильно",
    "Not before %lld mo": "Не раньше %lld мес",
    "From %lld mo": "С %lld мес",
    "Usually from %lld mo": "Обычно с %lld мес",
    "Your doctor's date": "Дата вашего врача",

    # --- Food detail -----------------------------------------------------------
    "Suitable now": "Подходит сейчас",
    "Allowed from now": "Можно с этого возраста",
    "Usually from %lld months": {"one": "Обычно с %lld месяца", "few": "Обычно с %lld месяцев",
                                 "many": "Обычно с %lld месяцев", "other": "Обычно с %lld месяцев"},
    "Not before %lld months": {"one": "Не раньше %lld месяца", "few": "Не раньше %lld месяцев",
                               "many": "Не раньше %lld месяцев", "other": "Не раньше %lld месяцев"},
    "Your baby is %@ months old.": "Вашему ребёнку %@ мес.",
    "Your baby is %@ months old. Nothing here says it is unsafe today — this is the age most guidance suggests.":
        "Вашему ребёнку %@ мес. Ничто здесь не говорит, что сегодня это опасно, — просто такой возраст советует большинство рекомендаций.",
    "This is a hard limit with a safety reason behind it, not a preference. Read the sources below.":
        "Это жёсткое ограничение с механизмом безопасности за ним, а не вопрос предпочтений. Прочитайте источники ниже.",
    "How to serve at 6–8 months": "Как подавать в 6–8 месяцев",
    "How to serve from 9 months": "Как подавать с 9 месяцев",
    "Earlier, at 6–8 months": "Раньше, в 6–8 месяцев",
    "Later, from 9 months": "Позже, с 9 месяцев",
    "Contains %@ — one of the top-9 allergens. Offer it at home, earlier in the day, and keep it in the diet once it goes well.":
        "Содержит «%@» — один из топ-9 аллергенов. Давайте дома, в первой половине дня, и оставьте в рационе, если всё прошло хорошо.",
    "Cut with care — this food can form a choking shape if served whole or in coins.":
        "Режьте аккуратно — целиком или кружочками этот продукт принимает опасную форму.",
    "High choking risk. Follow the serving instructions exactly, keep your baby seated and upright, and stay within arm's reach.":
        "Высокий риск подавиться. Строго следуйте инструкции по подаче, сажайте ребёнка прямо и оставайтесь на расстоянии вытянутой руки.",
    "Rich in": "Богат",
    "Worth knowing": "Важно знать",
    "Your baby's history": "История вашего ребёнка",
    "Tried once, on %@.": "Пробовали один раз, %@.",
    "%1$lld times since %2$@. Last offered %3$@.": "Раз: %1$lld, с %2$@. Последний раз — %3$@.",
    "Where this comes from": "Откуда это взято",
    "Log this food": "Записать этот продукт",
    "My paediatrician said otherwise": "Мой педиатр сказал иначе",
    "When may we start %@?": "Когда можно начинать «%@»?",
    "If your paediatrician gave you a different age, put it here. Tummi will use your date and still show you what the published guidance says.":
        "Если ваш педиатр назвал другой возраст, укажите его здесь. Tummi будет использовать вашу дату и всё равно покажет, что говорят опубликованные рекомендации.",
    "Your plan: from %@ months.": "Ваш план: с %@ мес.",
    "Your plan: from %1$@ months — %2$@.": "Ваш план: с %1$@ мес — %2$@.",

    # --- Plan ------------------------------------------------------------------
    "No plan yet": "Плана пока нет",
    "Add a baby to see the guidance for their age.":
        "Добавьте ребёнка, чтобы увидеть рекомендации для его возраста.",
    "Daily targets": "Ориентиры на день",
    "Follow my paediatrician's numbers": "Следовать цифрам моего педиатра",
    "Follow my doctor's numbers": "Следовать цифрам моего врача",
    "Milk feeds a day": "Кормлений молоком в день",
    "Milk a day": "Молока в день",
    "Meals a day": "Приёмов пищи в день",
    "Snacks a day": "Перекусов в день",
    "Food per meal": "Еды за приём",
    "Energy from solids": "Калорий из прикорма",
    "about %lld kcal a day": "около %lld ккал в день",
    "Your paediatrician's numbers are in use.": "Используются цифры вашего педиатра.",
    "Your paediatrician's numbers are in use — %@.": "Используются цифры вашего педиатра — %@.",
    "Tap any number below to replace it with the one your doctor gave you.":
        "Нажмите на любую цифру ниже, чтобы заменить её на ту, что дал ваш врач.",
    "Enter the number your paediatrician gave you. Tummi will use it as the plan and keep showing the published range alongside, so you always know both.":
        "Введите цифру, которую назвал ваш педиатр. Tummi возьмёт её за план и продолжит показывать рядом опубликованный диапазон, чтобы вы всегда видели оба.",
    "Value": "Значение",
    "Who said so": "Кто назначил",
    "e.g. Dr Ivanova, 12 Aug": "напр. Иванова А.П., 12 авг.",
    "Shown next to every number this changes, so you can always tell your doctor's plan from the published ranges.":
        "Показывается рядом с каждой изменённой цифрой, чтобы вы всегда отличали план врача от опубликованных диапазонов.",
    "Use my doctor's number": "Использовать цифру врача",
    "Go back to published guidance": "Вернуться к опубликованным рекомендациям",
    "already applies": "уже актуально",
    "within a month": "в течение месяца",
    "in %lld months": {"one": "через %lld месяц", "few": "через %lld месяца",
                       "many": "через %lld месяцев", "other": "через %lld месяцев"},
    "Every source Tummi uses": "Все источники Tummi",
    "Tummi does not have opinions of its own. Everything it says traces to one of these.":
        "У Tummi нет собственного мнения. Всё, что оно говорит, восходит к одному из этих источников.",
    "meals": "приёмов",

    # --- Growth ----------------------------------------------------------------
    "WHO Child Growth Standards": "Стандарты роста детей ВОЗ",
    "Weight": "Вес",
    "Length": "Длина",
    "Head": "Голова",
    "Head circumference": "Окружность головы",
    "Date": "Дата",
    "Measurement": "Измерение",
    "No measurements yet": "Измерений пока нет",
    "Add a weight or a length and Tummi will plot it against the WHO curves for your baby's age and sex.":
        "Добавьте вес или длину, и Tummi нанесёт их на кривые ВОЗ для возраста и пола вашего ребёнка.",
    "Against the WHO curves": "На фоне кривых ВОЗ",
    "%@th percentile": "%@-й перцентиль",
    "p%@": "п%@",
    "median": "медиана",
    "your baby": "ваш ребёнок",
    "months": "месяцев",
    "Month": "Месяц",
    "Within the usual range. What matters is that the curve keeps its own shape over months, not any single reading.":
        "В пределах обычного диапазона. Важно не отдельное измерение, а то, что кривая держит свою форму на протяжении месяцев.",
    "Below the WHO −2 SD line. That is a threshold clinicians look at — worth mentioning at your next visit, and sooner if it is a change from before.":
        "Ниже линии −2 SD по ВОЗ. Это порог, на который смотрят врачи, — стоит упомянуть на ближайшем приёме, а если это изменение по сравнению с прошлым, то и раньше.",
    "Above the WHO +2 SD line. Often simply a big, healthy baby — worth mentioning at your next visit so someone who can examine your child takes a look.":
        "Выше линии +2 SD по ВОЗ. Часто это просто крупный здоровый ребёнок — стоит упомянуть на ближайшем приёме, чтобы посмотрел тот, кто может осмотреть ребёнка.",
    "What a percentile means": "Что означает перцентиль",
    "The 30th percentile means 30 of 100 healthy babies of the same age and sex weigh less. There is no good or bad number — a baby tracking steadily along the 15th is thriving, and a baby dropping from the 75th to the 25th is worth a conversation even though both numbers look fine.":
        "30-й перцентиль означает, что 30 из 100 здоровых детей того же возраста и пола весят меньше. Хороших и плохих цифр здесь нет: ребёнок, стабильно идущий по 15-му, растёт прекрасно, а ребёнок, съехавший с 75-го на 25-й, — повод для разговора, хотя обе цифры выглядят нормально.",
    "Leave a field blank if you did not measure it. Length is measured lying down until 2 years.":
        "Оставьте поле пустым, если не измеряли. До 2 лет длину измеряют лёжа.",

    # --- Settings --------------------------------------------------------------
    "Your baby": "Ваш ребёнок",
    "Preferences": "Предпочтения",
    "Appearance": "Оформление",
    "System": "Системное",
    "Light": "Светлое",
    "Dark": "Тёмное",
    "Your paediatrician's plan": "План вашего педиатра",
    "When this is on, the amounts and introduction ages you entered replace the published ranges throughout the app. The guidance stays visible underneath so you always see both.":
        "Когда включено, введённые вами количества и возрасты введения заменяют опубликованные диапазоны по всему приложению. Рекомендации остаются видны рядом, чтобы вы видели и то, и другое.",
    "Reset all my overrides": "Сбросить все мои изменения",
    "Your data": "Ваши данные",
    "Tummi has no account and no server. Everything lives in this app's storage on this device, and nothing is sent anywhere unless you export it yourself.":
        "У Tummi нет аккаунта и сервера. Всё живёт в хранилище приложения на этом устройстве, и никуда не отправляется, пока вы сами не сделаете экспорт.",
    "Export as JSON": "Экспорт в JSON",
    "Delete all data": "Удалить все данные",
    "Delete all data?": "Удалить все данные?",
    "Every feed, measurement and note for this child will be removed from this device. This cannot be undone.":
        "Все кормления, измерения и заметки об этом ребёнке будут удалены с устройства. Отменить это нельзя.",
    "Important": "Важно",
    "Tummi summarises published infant feeding guidance. It is not a medical device, it does not diagnose, and it cannot examine your baby. Always check with your paediatrician before making decisions about feeding, supplements or allergen introduction — and seek urgent care for breathing difficulty, facial swelling, repeated vomiting after a food, or a baby who stops feeding.":
        "Tummi пересказывает опубликованные рекомендации по питанию детей. Это не медицинское изделие, оно не ставит диагнозов и не может осмотреть вашего ребёнка. Всегда сверяйтесь с педиатром, принимая решения о питании, добавках и введении аллергенов, и обращайтесь за срочной помощью при затруднённом дыхании, отёке лица, многократной рвоте после продукта или если ребёнок перестал есть.",

    # --- Units and short forms -------------------------------------------------
    "g": "г",
    "ml": "мл",
    "kg": "кг",
    "cm": "см",
    "min": "мин",
    "h": "ч",
    "oz": "унц",
    "lb": "фунт",
    "fl oz": "жидк. унц",
    "in": "дюйм",
    "%lldd": "%lldд",
    "%lldw": "%lldнед",
    "%lldmo": "%lldмес",
    "%lldy": "%lldг",
    "%1$lldmo %2$lldw": "%1$lldмес %2$lldнед",
    "%1$lldy %2$lldmo": "%1$lldг %2$lldмес",
    "just now": "только что",
    "%lldm ago": "%lld мин назад",
    "%lldh ago": "%lld ч назад",
    "%1$lldh %2$lldm ago": "%1$lld ч %2$lld мин назад",

    # --- Reminders -------------------------------------------------------------
    "Reminders": "Напоминания",
    "Three reminders, and nothing else. Tummi will never nag you about feeds — you already know when your baby is hungry.":
        "Три напоминания и больше ничего. Tummi никогда не будет напоминать о кормлениях — вы и так знаете, когда ребёнок голоден.",
    "Allergen upkeep": "Поддержание аллергенов",
    "Weekly, only when something introduced has been quietly dropped":
        "Раз в неделю и только если введённое незаметно перестали давать",
    "Weigh-in nudge": "Напоминание о взвешивании",
    "When it has been a while since the last measurement":
        "Когда с последнего измерения прошло много времени",
    "New stage": "Новый этап",
    "At 4, 6, 9, 12 and 24 months, when the guidance changes":
        "В 4, 6, 9, 12 и 24 месяца, когда меняются рекомендации",
    "Notifications are turned off for Tummi in iOS Settings, so these will not appear.":
        "Уведомления для Tummi выключены в настройках iOS — эти напоминания не появятся.",
    "Keep the allergens going": "Не бросайте аллергены",
    "%@ was introduced but has not been offered lately. Regular exposure is what the prevention trials tested.":
        "«%@» уже вводили, но давно не давали. В исследованиях по профилактике проверяли именно регулярность.",
    "These were introduced but have not been offered lately: %@.":
        "Эти уже вводили, но давно не давали: %@.",
    "Time for a weigh-in": "Пора взвесить",
    "A single measurement is just a number. Add one and Tummi can start showing the curve.":
        "Одно измерение — просто число. Добавьте его, и Tummi начнёт строить кривую.",
    "It has been a while since the last measurement. One more point keeps the curve honest.":
        "С последнего измерения прошло много времени. Ещё одна точка — и кривая останется честной.",
    "New stage: %@": "Новый этап: %@",

    # --- Siri and Shortcuts ----------------------------------------------------
    "Logging": "Запись",
    "Information": "Информация",
    "Log a bottle": "Записать бутылочку",
    "Log a meal": "Записать приём пищи",
    "How much today": "Сколько сегодня",
    "Records a bottle feed for the current baby.":
        "Записывает кормление из бутылочки текущему ребёнку.",
    "Records how much solid food the baby ate. Which foods and how it went can be added in the app.":
        "Записывает, сколько прикорма съел ребёнок. Какие продукты и как прошло — можно добавить в приложении.",
    "Reads back today's milk and solid food against the guidance range for the baby's age.":
        "Зачитывает, сколько молока и еды сегодня, относительно диапазона для возраста ребёнка.",
    "Amount in millilitres": "Объём в миллилитрах",
    "Amount in grams": "Количество в граммах",
    # The ${…} tokens are parameter references and must survive translation verbatim.
    "Log a ${millilitres} ml bottle": "Записать бутылочку ${millilitres} мл",
    "Log a ${grams} g meal": "Записать приём пищи ${grams} г",
    "Add a baby in Tummi first.": "Сначала добавьте ребёнка в Tummi.",
    "Logged.": "Записано.",
    "Logged. %1$@ so far today.": "Записано. Сегодня уже %1$@.",
    "Nothing logged yet today.": "Сегодня пока ничего не записано.",
    "%1$@ of milk": "%1$@ молока",
    "%1$lld milk feeds": "молочных кормлений: %1$lld",
    "%1$@ of food across %2$lld meals": "%1$@ еды за %2$lld приёмов",
    "Today's guidance range is %1$@ across %2$@ meals.":
        "Ориентир на сегодня — %1$@ за %2$@ приёмов.",

    # --- Widget ----------------------------------------------------------------
    "Food today": "Еда сегодня",
    "Milk": "Молоко",
    "%lld feeds": "кормлений: %lld",
    "%1$lld of %2$lld–%3$lld meals": "приёмов: %1$lld из %2$lld–%3$lld",
    "Keep up: %@": "Не бросайте: %@",
    "Open Tummi to get started": "Откройте Tummi, чтобы начать",
    "Today's food and milk against the guidance range for your baby's age.":
        "Еда и молоко за сегодня относительно диапазона для возраста ребёнка.",

    # --- Onboarding tour -------------------------------------------------------
    "How Tummi works": "Как устроено Tummi",
    "Five screens. You will mostly live on the first one.":
        "Пять экранов. Жить вы будете в основном на первом.",
    "Log a feed in two taps and see how the day compares to the range for your baby's age.":
        "Записать кормление в два касания и увидеть, как день соотносится с нормой для возраста.",
    "Everything you have recorded, newest first. Tap any entry to correct it.":
        "Всё, что вы записали, сначала свежее. Нажмите на запись, чтобы поправить.",
    "148 foods: when each is usually introduced, whether it is an allergen, and exactly how to cut it.":
        "148 продуктов: когда каждый обычно вводят, аллерген ли это и как именно резать.",
    "What the guidance says at this stage, what is coming next — and where you enter your paediatrician's own numbers.":
        "Что рекомендации говорят на этом этапе, что будет дальше — и где вписать цифры своего педиатра.",
    "Weight, length and head circumference on the real WHO curves.":
        "Вес, длина и окружность головы на настоящих кривых ВОЗ.",
    "The green chips are links": "Зелёные плашки — это ссылки",
    "Under every recommendation you will see something like “WHO, 2023”. Tap it and the actual guideline opens. Nothing in Tummi asks you to take its word for it.":
        "Под каждой рекомендацией вы увидите что-то вроде «WHO, 2023». Нажмите — откроется сам гайд. Tummi нигде не просит верить на слово.",
    "Got it": "Понятно",

    # --- Empty states and first-run hints --------------------------------------
    "Tap any source to read it": "Нажмите на источник, чтобы прочитать",
    "The little green chips under each card open the guideline or study it came from. That is the whole point of Tummi — nothing here asks you to take its word for it.":
        "Маленькие зелёные плашки под каждой карточкой открывают гайд или исследование, откуда взята рекомендация. В этом весь смысл Tummi: оно не просит верить на слово.",
    "Use the buttons above": "Кнопки сверху",
    "Today's guidance is %1$@ meals and about %2$@ of food. Log a feed and Tummi will start tracking against it.":
        "Ориентир на сегодня — %1$@ приёмов пищи и около %2$@ еды. Запишите кормление, и Tummi начнёт сверять.",
    "Today's guidance is %1$@ milk feeds. Log one and Tummi will start tracking against it.":
        "Ориентир на сегодня — %1$@ молочных кормлений. Запишите одно, и Tummi начнёт сверять.",
    "Log a feed and Tummi will start tracking it against the guidance for this age.":
        "Запишите кормление, и Tummi начнёт сверять его с рекомендациями для этого возраста.",
    "Record something": "Сделать запись",
    "Every feed, nappy and nap you record shows up here, newest first, grouped by day.":
        "Все кормления, подгузники и сны появляются здесь — сначала свежие, сгруппированные по дням.",
    "Add a measurement": "Добавить измерение",
    "Add your baby": "Добавить ребёнка",
    "Tummi needs a date of birth to know which guidance applies.":
        "Tummi нужна дата рождения, чтобы понять, какие рекомендации применять.",
}

# Purely structural strings — the English "translation" is the correct Russian one too.
PASSTHROUGH = {"Tummi", "Series", "0", "—", "/ %@", "%1$@ %2$@", "%1$@ · %2$@"}

# English needs plural variations too, or a baby with one exposure reads "1 exposures".
# Only single-argument count strings that can legitimately be 1 are listed; the presenters
# branch on the singular case for the rest.
EN_PLURALS = {
    "%lld exposures so far. The prevention trials relied on eating it regularly — roughly twice a week — not on a single taste.": {
        "one": "%lld exposure so far. The prevention trials relied on eating it regularly — roughly twice a week — not on a single taste.",
        "other": "%lld exposures so far. The prevention trials relied on eating it regularly — roughly twice a week — not on a single taste.",
    },
    "%lld milk feeds": {"one": "%lld milk feed", "other": "%lld milk feeds"},
    "%lld feeds": {"one": "%lld feed", "other": "%lld feeds"},
    "%lld weeks at birth": {"one": "%lld week at birth", "other": "%lld weeks at birth"},
}


def source_keys(xliff_path: Path) -> list[str]:
    ns = {"x": "urn:oasis:names:tc:xliff:document:1.2"}
    tree = ET.parse(xliff_path)
    keys: list[str] = []
    for file_node in tree.getroot().findall("x:file", ns):
        if not file_node.get("original", "").endswith("Localizable.xcstrings"):
            continue
        for unit in file_node.findall("x:body/x:trans-unit", ns):
            source = unit.find("x:source", ns)
            if source is not None and source.text:
                keys.append(source.text)
    return sorted(set(keys))


def unit(value: str) -> dict:
    return {"stringUnit": {"state": "translated", "value": value}}


def build(keys: list[str]) -> tuple[dict, list[str]]:
    strings: dict = {}
    missing: list[str] = []

    # The exporter re-reads the catalogue, so English plural *values* come back as if they
    # were source keys. They are never looked up at runtime — drop them instead of asking
    # for a translation of a string that does not exist in the code.
    plural_values = {text for forms in EN_PLURALS.values() for text in forms.values()}

    for key in keys:
        if key in plural_values and key not in EN_PLURALS:
            continue
        translation = RU.get(key)
        if translation is None:
            if key in PASSTHROUGH:
                strings[key] = {"extractionState": "manual", "shouldTranslate": False}
                continue
            missing.append(key)
            strings[key] = {}
            continue

        if isinstance(translation, dict):
            ru_entry = {
                "variations": {
                    "plural": {form: unit(text) for form, text in translation.items()}
                }
            }
        else:
            ru_entry = unit(translation)

        localizations = {"ru": ru_entry}
        if key in EN_PLURALS:
            localizations["en"] = {
                "variations": {
                    "plural": {form: unit(text) for form, text in EN_PLURALS[key].items()}
                }
            }
        strings[key] = {"localizations": localizations}

    return {"sourceLanguage": "en", "strings": strings, "version": "1.0"}, missing


def main() -> int:
    xliff = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(
        "/tmp/tummi_loc/ru.xcloc/Localized Contents/ru.xliff")
    keys = source_keys(xliff)
    catalogue, missing = build(keys)

    out = Path(__file__).resolve().parent.parent / "Tummi" / "Localizable.xcstrings"
    out.write_text(json.dumps(catalogue, ensure_ascii=False, indent=2, sort_keys=True) + "\n")

    print(f"wrote {out} — {len(keys)} keys, {len(missing)} untranslated")
    for key in missing:
        print("  MISSING:", key)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
