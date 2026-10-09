extends RefCounted
class_name TextbornCharacterRig

# Adult stylized anatomy in local pixels. Feet sit near y=0; head is ~8 head-heights above hips.
const HEAD_CENTER := Vector2(0.0, -108.0)
const HEAD_RADIUS := Vector2(6.5, 8.5)

func build_pose(gait: float, blend: float) -> Dictionary:
    var stride := sin(gait) * 7.5 * blend
    var lift_left := maxf(0.0, sin(gait)) * 2.0 * blend
    var lift_right := maxf(0.0, -sin(gait)) * 2.0 * blend
    var bob := absf(sin(gait * 2.0)) * 0.8 * blend
    var pelvis := Vector2(0.0, -47.0 + bob)
    var chest := Vector2(-stride * 0.025, -81.0 + bob)
    var neck := chest + Vector2(0.0, -7.5)
    var head := neck + Vector2(0.0, -13.5)

    var lhip := pelvis + Vector2(-4.5, 0.0)
    var rhip := pelvis + Vector2(4.5, 0.0)
    var lknee := lhip + Vector2(stride * 0.48, 18.0)
    var rknee := rhip + Vector2(-stride * 0.48, 18.0)
    var lankle := lknee + Vector2(stride * 0.52, 20.0 - lift_left)
    var rankle := rknee + Vector2(-stride * 0.52, 20.0 - lift_right)

    var lshoulder := chest + Vector2(-9.0, 1.5)
    var rshoulder := chest + Vector2(9.0, 1.5)
    var arm_swing := sin(gait) * 3.0 * blend
    var lelbow := lshoulder + Vector2(-1.0 - arm_swing * 0.35, 13.0)
    var relbow := rshoulder + Vector2(1.0 + arm_swing * 0.35, 13.0)
    var lhand := lelbow + Vector2(-arm_swing, 12.0)
    var rhand := relbow + Vector2(arm_swing, 12.0)

    return {
        "head": head, "neck": neck, "chest": chest, "pelvis": pelvis,
        "left_shoulder": lshoulder, "right_shoulder": rshoulder,
        "left_elbow": lelbow, "right_elbow": relbow,
        "left_hand": lhand, "right_hand": rhand,
        "left_hip": lhip, "right_hip": rhip,
        "left_knee": lknee, "right_knee": rknee,
        "left_ankle": lankle, "right_ankle": rankle,
    }
