extends RefCounted
class_name TextbornCharacterRig

# Slightly elevated three-quarter side view. Joint lengths remain consistent;
# the far side is offset in depth so both legs don't collapse into one line.
const THIGH_LENGTH: float = 19.0
const CALF_LENGTH: float = 21.0

func build_pose(gait: float, blend: float) -> Dictionary:
    var cycle := gait
    var stride_angle := sin(cycle) * 0.34 * blend
    var far_stride_angle := sin(cycle + PI) * 0.34 * blend
    var knee_bend_near := 0.10 + maxf(0.0, sin(cycle)) * 0.30 * blend
    var knee_bend_far := 0.10 + maxf(0.0, -sin(cycle)) * 0.30 * blend
    var lift_near := maxf(0.0, sin(cycle)) * 2.0 * blend
    var lift_far := maxf(0.0, -sin(cycle)) * 2.0 * blend
    var bob := absf(sin(cycle * 2.0)) * 0.65 * blend

    var pelvis := Vector2(0.0, -49.0 + bob)
    var chest := Vector2(-sin(cycle) * 0.45 * blend, -82.0 + bob)
    var neck := chest + Vector2(0.0, -7.0)
    var head := neck + Vector2(0.0, -13.0)

    # Slight perspective: near-side joints sit a few pixels forward/right.
    var near_hip := pelvis + Vector2(3.0, 0.0)
    var far_hip := pelvis + Vector2(-3.0, 1.0)

    var near_thigh_angle := stride_angle
    var far_thigh_angle := far_stride_angle
    var near_knee := near_hip + Vector2(sin(near_thigh_angle) * THIGH_LENGTH, cos(near_thigh_angle) * THIGH_LENGTH)
    var far_knee := far_hip + Vector2(sin(far_thigh_angle) * THIGH_LENGTH, cos(far_thigh_angle) * THIGH_LENGTH)

    # Knee flex is strongest during swing, subtle during stance.
    var near_calf_angle := near_thigh_angle - knee_bend_near
    var far_calf_angle := far_thigh_angle - knee_bend_far
    var near_ankle := near_knee + Vector2(sin(near_calf_angle) * CALF_LENGTH, cos(near_calf_angle) * CALF_LENGTH - lift_near)
    var far_ankle := far_knee + Vector2(sin(far_calf_angle) * CALF_LENGTH, cos(far_calf_angle) * CALF_LENGTH - lift_far)

    var left_shoulder := chest + Vector2(-9.0, 1.5)
    var right_shoulder := chest + Vector2(9.0, 1.5)
    var arm_swing := sin(cycle + PI) * 3.0 * blend
    var left_elbow := left_shoulder + Vector2(-1.0 - arm_swing * 0.35, 13.0)
    var right_elbow := right_shoulder + Vector2(1.0 + arm_swing * 0.35, 13.0)
    var left_hand := left_elbow + Vector2(-arm_swing, 12.0)
    var right_hand := right_elbow + Vector2(arm_swing, 12.0)

    return {
        "head": head, "neck": neck, "chest": chest, "pelvis": pelvis,
        "left_shoulder": left_shoulder, "right_shoulder": right_shoulder,
        "left_elbow": left_elbow, "right_elbow": right_elbow,
        "left_hand": left_hand, "right_hand": right_hand,
        # left = far leg; right = near leg, with explicit depth ordering.
        "left_hip": far_hip, "right_hip": near_hip,
        "left_knee": far_knee, "right_knee": near_knee,
        "left_ankle": far_ankle, "right_ankle": near_ankle,
    }
