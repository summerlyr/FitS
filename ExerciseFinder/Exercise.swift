import Foundation

struct Exercise: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let nameZh: String?
    let category: String
    let bodyPart: String
    let equipment: String
    let instructions: [String: String]
    let instructionSteps: [String: [String]]
    let muscleGroup: String
    let secondaryMuscles: [String]
    let target: String
    let image: String
    let gifURL: String
    let attribution: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case nameZh = "name_zh"
        case category
        case bodyPart = "body_part"
        case equipment
        case instructions
        case instructionSteps = "instruction_steps"
        case muscleGroup = "muscle_group"
        case secondaryMuscles = "secondary_muscles"
        case target
        case image
        case gifURL = "gif_url"
        case attribution
    }

    var localizedName: String {
        nameZh?.nonEmpty ?? name.capitalized
    }

    var searchableTerms: String {
        [
            name,
            localizedName,
            bodyPart,
            ExerciseTerms.localized(bodyPart),
            equipment,
            ExerciseTerms.localized(equipment),
            target,
            ExerciseTerms.localized(target)
        ].joined(separator: " ")
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

enum ExerciseTerms {
    private static let translations: [String: String] = [
        "back": "背部",
        "cardio": "有氧",
        "chest": "胸部",
        "lower arms": "前臂",
        "lower legs": "小腿",
        "neck": "颈部",
        "shoulders": "肩部",
        "upper arms": "上臂",
        "upper legs": "大腿",
        "waist": "腰腹",
        "abductors": "髋外展肌",
        "abdominals": "腹肌",
        "abs": "腹肌",
        "adductors": "髋内收肌",
        "ankle stabilizers": "踝关节稳定肌",
        "ankles": "脚踝",
        "biceps": "肱二头肌",
        "brachialis": "肱肌",
        "calves": "小腿肌群",
        "cardiovascular system": "心肺系统",
        "core": "核心肌群",
        "deltoids": "三角肌",
        "delts": "三角肌",
        "feet": "足部肌群",
        "forearms": "前臂肌群",
        "glutes": "臀肌",
        "grip muscles": "握力肌群",
        "groin": "腹股沟肌群",
        "hamstrings": "腘绳肌",
        "hands": "手部肌群",
        "hip flexors": "髋屈肌",
        "inner thighs": "大腿内侧肌群",
        "latissimus dorsi": "背阔肌",
        "lats": "背阔肌",
        "levator scapulae": "肩胛提肌",
        "lower abs": "下腹肌",
        "lower back": "下背部肌群",
        "obliques": "腹斜肌",
        "pectorals": "胸肌",
        "quads": "股四头肌",
        "quadriceps": "股四头肌",
        "rear deltoids": "三角肌后束",
        "rhomboids": "菱形肌",
        "rotator cuff": "肩袖肌群",
        "serratus anterior": "前锯肌",
        "shins": "胫骨前肌",
        "soleus": "比目鱼肌",
        "spine": "竖脊肌（下背）",
        "sternocleidomastoid": "胸锁乳突肌",
        "trapezius": "斜方肌",
        "traps": "斜方肌",
        "triceps": "肱三头肌",
        "upper back": "上背部肌群",
        "upper chest": "上胸肌",
        "wrist extensors": "腕伸肌",
        "wrist flexors": "腕屈肌",
        "wrists": "腕部肌群",
        "assisted": "辅助器械",
        "band": "弹力带",
        "barbell": "杠铃",
        "body weight": "自重",
        "bosu ball": "波速球",
        "cable": "绳索器械",
        "dumbbell": "哑铃",
        "elliptical machine": "椭圆机",
        "ez barbell": "曲杆杠铃",
        "hammer": "锤",
        "kettlebell": "壶铃",
        "leverage machine": "固定器械",
        "medicine ball": "药球",
        "olympic barbell": "奥林匹克杠铃",
        "resistance band": "阻力带",
        "roller": "泡沫轴",
        "rope": "绳",
        "skierg machine": "滑雪机",
        "sled machine": "雪橇机",
        "smith machine": "史密斯机",
        "stability ball": "健身球",
        "stationary bike": "健身车",
        "stepmill machine": "登阶机",
        "tire": "轮胎",
        "trap bar": "六角杠铃",
        "upper body ergometer": "上肢测功机",
        "weighted": "负重",
        "wheel roller": "健腹轮"
    ]

    static func localized(_ value: String) -> String {
        translations[value] ?? value.capitalized
    }
}
