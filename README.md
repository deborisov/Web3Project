# Описание проекта

СмК позволяющий играть в рулетку. Доступны ставки на четное/нечетное или на конкретное число.
Контракту передеется хеш случайного числа игрока и адреса игрока, чтобы СмК не смог смухлевать при подсчете резуьтатов.
После этого запрашивается случайное число через ChainLink.
После этого игрок ревилит свое случайное число. Значение выпавшего числа = (число игрока ^ случайное число от chainlink) % 37.
Происходит расчет по выпавшему числу и ставке.

# Адрес СМК c кодом рулетки

0xE631ec0F77fE2Dfcf16c77F00561E1A0a5e17B32