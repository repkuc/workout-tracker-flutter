# Exercise animations: mapping to free-exercise-db

Decision (2026-10-15): for the first version of exercise demo animations we use **free-exercise-db** (github.com/yuhonas/free-exercise-db), released under the **Unlicense** (public domain), so it can be bundled in the app. Each exercise has 2 photos (start/end position); the app alternates them (~0.6 s) to show the movement.

Image URL pattern: `https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/<image path>` (paths below). Plan: download, resize (~320 px), bundle under assets, add an image field to ExerciseTemplate. Custom user exercises have no image and keep the current icon.

All 48 built-in exercises (`assets/exercises/exercises.json`) are matched and were reviewed visually by Arturs.

| App id | Our name (RU) | Our name (EN) | free-exercise-db name | Images |
|---|---|---|---|---|
| chest_1 | Жим штанги лёжа | Barbell Bench Press | Barbell Bench Press - Medium Grip | Barbell_Bench_Press_-_Medium_Grip/0.jpg, Barbell_Bench_Press_-_Medium_Grip/1.jpg |
| chest_2 | Жим гантелей лёжа | Dumbbell Bench Press | Dumbbell Bench Press | Dumbbell_Bench_Press/0.jpg, Dumbbell_Bench_Press/1.jpg |
| chest_3 | Жим штанги узким хватом | Close Grip Bench Press | Close-Grip Barbell Bench Press | Close-Grip_Barbell_Bench_Press/0.jpg, Close-Grip_Barbell_Bench_Press/1.jpg |
| chest_4 | Разводка гантелей лёжа | Dumbbell Flyes | Dumbbell Flyes | Dumbbell_Flyes/0.jpg, Dumbbell_Flyes/1.jpg |
| chest_5 | Жим в тренажёре | Machine Chest Press | Leverage Chest Press | Leverage_Chest_Press/0.jpg, Leverage_Chest_Press/1.jpg |
| chest_6 | Кроссовер на блоке | Cable Crossover | Cable Crossover | Cable_Crossover/0.jpg, Cable_Crossover/1.jpg |
| chest_7 | Отжимания на брусьях | Dips | Dips - Chest Version | Dips_-_Chest_Version/0.jpg, Dips_-_Chest_Version/1.jpg |
| chest_8 | Жим на наклонной скамье | Incline Bench Press | Barbell Incline Bench Press - Medium Grip | Barbell_Incline_Bench_Press_-_Medium_Grip/0.jpg, Barbell_Incline_Bench_Press_-_Medium_Grip/1.jpg |
| back_1 | Подтягивания | Pull-ups | Pullups | Pullups/0.jpg, Pullups/1.jpg |
| back_2 | Тяга штанги в наклоне | Barbell Row | Bent Over Barbell Row | Bent_Over_Barbell_Row/0.jpg, Bent_Over_Barbell_Row/1.jpg |
| back_3 | Тяга гантели одной рукой | One Arm Dumbbell Row | One-Arm Dumbbell Row | One-Arm_Dumbbell_Row/0.jpg, One-Arm_Dumbbell_Row/1.jpg |
| back_4 | Тяга вертикального блока | Lat Pulldown | Wide-Grip Lat Pulldown | Wide-Grip_Lat_Pulldown/0.jpg, Wide-Grip_Lat_Pulldown/1.jpg |
| back_5 | Тяга горизонтального блока | Cable Row | Seated Cable Rows | Seated_Cable_Rows/0.jpg, Seated_Cable_Rows/1.jpg |
| back_6 | Становая тяга | Deadlift | Barbell Deadlift | Barbell_Deadlift/0.jpg, Barbell_Deadlift/1.jpg |
| back_7 | Гиперэкстензия | Hyperextension | Hyperextensions (Back Extensions) | Hyperextensions_Back_Extensions/0.jpg, Hyperextensions_Back_Extensions/1.jpg |
| back_8 | Тяга Т-грифа | T-Bar Row | T-Bar Row with Handle | T-Bar_Row_with_Handle/0.jpg, T-Bar_Row_with_Handle/1.jpg |
| legs_1 | Приседания со штангой | Barbell Squat | Barbell Squat | Barbell_Squat/0.jpg, Barbell_Squat/1.jpg |
| legs_2 | Жим платформы ногами | Leg Press | Leg Press | Leg_Press/0.jpg, Leg_Press/1.jpg |
| legs_3 | Разгибание ног в тренажёре | Leg Extension | Leg Extensions | Leg_Extensions/0.jpg, Leg_Extensions/1.jpg |
| legs_4 | Сгибание ног в тренажёре | Leg Curl | Lying Leg Curls | Lying_Leg_Curls/0.jpg, Lying_Leg_Curls/1.jpg |
| legs_5 | Выпады со штангой | Barbell Lunges | Barbell Lunge | Barbell_Lunge/0.jpg, Barbell_Lunge/1.jpg |
| legs_6 | Икры стоя | Standing Calf Raise | Standing Calf Raises | Standing_Calf_Raises/0.jpg, Standing_Calf_Raises/1.jpg |
| legs_7 | Икры сидя | Seated Calf Raise | Seated Calf Raise | Seated_Calf_Raise/0.jpg, Seated_Calf_Raise/1.jpg |
| legs_8 | Румынская тяга | Romanian Deadlift | Romanian Deadlift | Romanian_Deadlift/0.jpg, Romanian_Deadlift/1.jpg |
| shoulders_1 | Армейский жим | Military Press | Standing Military Press | Standing_Military_Press/0.jpg, Standing_Military_Press/1.jpg |
| shoulders_2 | Жим гантелей сидя | Dumbbell Shoulder Press | Dumbbell Shoulder Press | Dumbbell_Shoulder_Press/0.jpg, Dumbbell_Shoulder_Press/1.jpg |
| shoulders_3 | Махи гантелями в стороны | Lateral Raises | Side Lateral Raise | Side_Lateral_Raise/0.jpg, Side_Lateral_Raise/1.jpg |
| shoulders_4 | Махи гантелями вперёд | Front Raises | Front Dumbbell Raise | Front_Dumbbell_Raise/0.jpg, Front_Dumbbell_Raise/1.jpg |
| shoulders_5 | Тяга штанги к подбородку | Upright Row | Upright Barbell Row | Upright_Barbell_Row/0.jpg, Upright_Barbell_Row/1.jpg |
| shoulders_6 | Разводка гантелей в наклоне | Rear Delt Flyes | Seated Bent-Over Rear Delt Raise | Seated_Bent-Over_Rear_Delt_Raise/0.jpg, Seated_Bent-Over_Rear_Delt_Raise/1.jpg |
| shoulders_7 | Жим в тренажёре на плечи | Machine Shoulder Press | Machine Shoulder (Military) Press | Machine_Shoulder_Military_Press/0.jpg, Machine_Shoulder_Military_Press/1.jpg |
| shoulders_8 | Шраги со штангой | Barbell Shrugs | Barbell Shrug | Barbell_Shrug/0.jpg, Barbell_Shrug/1.jpg |
| arms_1 | Подъём штанги на бицепс | Barbell Curl | Barbell Curl | Barbell_Curl/0.jpg, Barbell_Curl/1.jpg |
| arms_2 | Подъём гантелей на бицепс | Dumbbell Curl | Dumbbell Bicep Curl | Dumbbell_Bicep_Curl/0.jpg, Dumbbell_Bicep_Curl/1.jpg |
| arms_3 | Молотки | Hammer Curl | Hammer Curls | Hammer_Curls/0.jpg, Hammer_Curls/1.jpg |
| arms_4 | Разгибание рук в блоке | Cable Tricep Pushdown | Triceps Pushdown | Triceps_Pushdown/0.jpg, Triceps_Pushdown/1.jpg |
| arms_5 | Французский жим | Skull Crushers | EZ-Bar Skullcrusher | EZ-Bar_Skullcrusher/0.jpg, EZ-Bar_Skullcrusher/1.jpg |
| arms_6 | Разгибание гантели за головой | Overhead Tricep Extension | Standing Dumbbell Triceps Extension | Standing_Dumbbell_Triceps_Extension/0.jpg, Standing_Dumbbell_Triceps_Extension/1.jpg |
| arms_7 | Концентрированный подъём | Concentration Curl | Concentration Curls | Concentration_Curls/0.jpg, Concentration_Curls/1.jpg |
| arms_8 | Отжимания на брусьях узким хватом | Close Grip Dips | Dips - Triceps Version | Dips_-_Triceps_Version/0.jpg, Dips_-_Triceps_Version/1.jpg |
| abs_1 | Скручивания | Crunches | Crunches | Crunches/0.jpg, Crunches/1.jpg |
| abs_2 | Планка | Plank | Plank | Plank/0.jpg, Plank/1.jpg |
| abs_3 | Подъём ног лёжа | Lying Leg Raises | Flat Bench Lying Leg Raise | Flat_Bench_Lying_Leg_Raise/0.jpg, Flat_Bench_Lying_Leg_Raise/1.jpg |
| abs_4 | Скручивания на блоке | Cable Crunches | Cable Crunch | Cable_Crunch/0.jpg, Cable_Crunch/1.jpg |
| abs_5 | Русский твист | Russian Twist | Russian Twist | Russian_Twist/0.jpg, Russian_Twist/1.jpg |
| abs_6 | Подъём ног в висе | Hanging Leg Raises | Hanging Leg Raise | Hanging_Leg_Raise/0.jpg, Hanging_Leg_Raise/1.jpg |
| abs_7 | Велосипед | Bicycle Crunches | Air Bike | Air_Bike/0.jpg, Air_Bike/1.jpg |
| abs_8 | Скалолаз | Mountain Climbers | Mountain Climbers | Mountain_Climbers/0.jpg, Mountain_Climbers/1.jpg |
