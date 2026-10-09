extends RefCounted
class_name TextbornCharacterRig

# Compact, lean proportions for a slightly elevated side view.
# Feet are animated first; knees are solved from fixed segment lengths so
# both legs keep matching anatomy instead of stretching independently.
const THIGH_LENGTH: float = 19.0
const CALF_LENGTH: float = 21.0
const FOOT_REST_Y: float = -8.0
const STEP_REACH: float = 8.0
const STEP_LIFT: float = 5.0

func build_pose(gait: float, blend: float) -> Dictionary:
    var stride := sin(gait)
    var opposite_stride := sin(gait + PI)
    var bob := absf(sin(gait * 2.0)) * 0.45 * blend
    var pelvis := Vector2(0.0, -49.0 + bob)
    var chest := Vector2(-stride * 0.25 * blend, -82.0 + bob)
    var neck := chest + Vector2(0.0, -7.0)
    var head := neck + Vector2(0.0, -13.0)

    var near_hip := pelvis + Vector2(2.2, 0.0)
    var far_hip := pelvis + Vector2(-2.2, 0.7)
    var near_x := stride * STEP_REACH * blend
    var far_x := opposite_stride * STEP_REACH * blend
    var near_lift := maxf(0.0, stride) * STEP_LIFT * blend
    var far_lift := maxf(0.0, opposite_stride) * STEP_LIFT * blend
    var near_ankle := Vector2(near_x + 2.0, FOOT_REST_Y - near_lift)
    var far_ankle := Vector2(far_x - 2.0, FOOT_REST_Y - far_lift)
    var near_knee := _solve_knee(near_hip, near_ankle, 1.0)
    var far_knee := _solve_knee(far_hip, far_ankle, -1.0)

    # Slim shoulder line and arms that counter-swing gently.
    var left_shoulder := chest + Vector2(-7.2, 1.0)
    var right_shoulder := chest + Vector2(7.2, 1.0)
    var arm_swing := stride * 2.4 * blend
    var left_elbow := left_shoulder + Vector2(-0.5 - arm_swing * 0.3, 12.0)
    var right_elbow := right_shoulder + Vector2(0.5 + arm_swing * 0.3, 12.0)
    var left_hand := left_elbow + Vector2(-arm_swing * 0.65, 11.0)
    var right_hand := right_elbow + Vector2(arm_swing * 0.65, 11.0)

    return {
        "head": head, "neck": neck, "chest": chest, "pelvis": pelvis,
        "left_shoulder": left_shoulder, "right_shoulder": right_shoulder,
        "left_elbow": left_elbow, "right_elbow": right_elbow,
        "left_hand": left_hand, "right_hand": right_hand,
        "left_hip": far_hip, "right_hip": near_hip,
        "left_knee": far_knee, "right_knee": near_knee,
        "left_ankle": far_ankle, "right_ankle": near_ankle,
    }

func _solve_knee(hip: Vector2, ankle: Vector2, bend_side: float) -> Vector2:
    var delta := ankle - hip
    var distance := clampf(delta.length(), 0.1, THIGH_LENGTH + CALF_LENGTH - 0.01)
    var direction := delta / maxf(delta.length(), 0.001)
    var along := (THIGH_LENGTH * THIGH_LENGTH - CALF_LENGTH * CALF_LENGTH + distance * distance) / (2.0 * distance)
    var height := sqrt(maxf(0.0, THIGH_LENGTH * THIGH_LENGTH - along * along))
    var perpendicular := Vector2(-direction.y, direction.x) * bend_side
    return hip + direction * along + perpendicular * height
