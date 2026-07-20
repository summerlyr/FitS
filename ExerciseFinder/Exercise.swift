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

    var chineseName: String {
        nameZh?.nonEmpty ?? name.capitalized
    }

    var localizedName: String {
        L10n.prefersEnglish ? name.capitalized : chineseName
    }

    var searchableTerms: String {
        [
            name,
            chineseName,
            ExerciseTerms.searchTerms(for: bodyPart),
            ExerciseTerms.searchTerms(for: equipment),
            ExerciseTerms.searchTerms(for: target)
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
        "cardio": "心肺训练",
        "chest": "胸部",
        "lower arms": "前臂",
        "lower legs": "小腿",
        "neck": "颈部",
        "shoulders": "肩部",
        "upper arms": "上臂",
        "upper legs": "大腿",
        "waist": "腰腹",
        "abductors": "髋外展肌群",
        "abdominals": "腹肌",
        "abs": "腹肌",
        "adductors": "髋内收肌群",
        "ankle stabilizers": "踝关节稳定肌",
        "ankles": "踝部",
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
        "lower back": "腰背部肌群",
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
        "spine": "竖脊肌",
        "sternocleidomastoid": "胸锁乳突肌",
        "trapezius": "斜方肌",
        "traps": "斜方肌",
        "triceps": "肱三头肌",
        "upper back": "上背肌群",
        "upper chest": "上胸肌",
        "wrist extensors": "腕伸肌",
        "wrist flexors": "腕屈肌",
        "wrists": "腕部肌群",
        "assisted": "辅助",
        "band": "弹力带",
        "barbell": "杠铃",
        "body weight": "自重",
        "bosu ball": "BOSU 平衡球",
        "cable": "绳索器械",
        "dumbbell": "哑铃",
        "elliptical machine": "椭圆机",
        "ez barbell": "曲杆杠铃",
        "hammer": "大锤",
        "kettlebell": "壶铃",
        "leverage machine": "杠杆式训练器",
        "medicine ball": "药球",
        "olympic barbell": "奥林匹克杠铃",
        "resistance band": "阻力带",
        "roller": "泡沫轴",
        "rope": "绳索",
        "skierg machine": "滑雪测功机",
        "sled machine": "雪橇式训练器",
        "smith machine": "史密斯机",
        "stability ball": "健身球",
        "stationary bike": "固定式健身车",
        "stepmill machine": "登阶机",
        "tire": "轮胎",
        "trap bar": "六角杠铃",
        "upper body ergometer": "上肢测功车",
        "weighted": "负重",
        "wheel roller": "健腹轮"
    ]

    private static let searchAliases: [String: [String]] = [
        "back": ["背", "后背", "背肌"],
        "cardio": ["有氧", "心肺", "有氧运动"],
        "chest": ["胸", "胸肌"],
        "lower arms": ["小臂", "前臂肌群"],
        "lower legs": ["小腿肌群"],
        "neck": ["颈", "脖子"],
        "shoulders": ["肩", "肩膀"],
        "upper arms": ["大臂"],
        "upper legs": ["腿部", "大腿肌群"],
        "waist": ["腰腹部", "腹部", "核心"],
        "abductors": ["外展肌", "髋外展", "大腿外侧"],
        "abs": ["腹直肌", "腹部", "核心", "abdominals"],
        "adductors": ["内收肌", "髋内收", "大腿内侧"],
        "biceps": ["肱二头", "二头肌", "二头"],
        "calves": ["小腿", "腓肠肌", "比目鱼肌"],
        "cardiovascular system": ["心肺", "有氧", "心血管系统"],
        "delts": ["三角肌群", "肩部", "肩膀", "deltoids"],
        "forearms": ["前臂", "小臂"],
        "glutes": ["臀肌群", "臀部", "gluteals"],
        "hamstrings": ["腘绳肌群", "大腿后侧", "腿后侧", "股后肌群"],
        "lats": ["阔背肌", "latissimus dorsi"],
        "levator scapulae": ["提肩胛肌"],
        "pectorals": ["胸大肌", "胸肌群", "pecs"],
        "quads": ["股四头肌群", "大腿前侧", "quadriceps"],
        "serratus anterior": ["前锯肌群"],
        "spine": ["下背", "下背部", "腰背", "腰背部", "脊柱肌群", "lower back", "erector spinae"],
        "traps": ["斜方肌群", "上背", "trapezius"],
        "triceps": ["肱三头", "三头肌", "三头"],
        "upper back": ["上背", "上背部", "背部上方"],
        "assisted": ["辅助器械", "助力"],
        "band": ["拉力带", "阻力带"],
        "body weight": ["徒手", "无器械", "自身重量"],
        "bosu ball": ["BOSU球", "波速球", "半圆平衡球"],
        "cable": ["绳索", "龙门架", "拉力器"],
        "ez barbell": ["EZ杆", "曲杆", "W杆"],
        "hammer": ["锤", "铁锤", "sledgehammer"],
        "leverage machine": ["固定器械", "杠杆器械", "训练机"],
        "medicine ball": ["实心球", "重力球"],
        "olympic barbell": ["奥杆", "奥林匹克杆"],
        "resistance band": ["弹力带", "拉力带"],
        "roller": ["滚筒", "按摩滚筒"],
        "rope": ["绳", "训练绳"],
        "skierg machine": ["滑雪机", "SkiErg"],
        "sled machine": ["雪橇机", "倒蹬机", "腿举机"],
        "stability ball": ["瑞士球", "瑜伽球", "抗力球"],
        "stationary bike": ["健身车", "动感单车", "室内单车"],
        "stepmill machine": ["楼梯机", "踏步机"],
        "trap bar": ["六角杆", "hex bar"],
        "upper body ergometer": ["上肢测功机", "手摇车", "手摇功率车"],
        "weighted": ["加重", "额外负重"],
        "wheel roller": ["腹肌轮", "健腹滚轮"]
    ]

    static func localizedChinese(_ value: String) -> String {
        translations[value] ?? value.capitalized
    }

    static func localized(_ value: String) -> String {
        L10n.prefersEnglish ? value.capitalized : localizedChinese(value)
    }

    static func searchTerms(for value: String) -> String {
        ([value, localizedChinese(value)] + (searchAliases[value] ?? []))
            .joined(separator: " ")
    }
}
