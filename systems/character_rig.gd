extends RefCounted
class_name TextbornCharacterRig

# A restrained walk cycle for a slightly elevated side view.
# Equal segment lengths and modest foot travel prevent knees snapping outward.
const THIGH_LENGTH: float = 23.0
const CALF_LENGTH: float = 23.0
const FOOT_REST_Y: float = -5.0
const STEP_REACH: float = 6.0
const STEP_LIFT: float = 3.0

func build_pose(gait: float, blend: float) -> Dictionary:
    var phase := fposmod(gait, TAU)
    var stride := sin(phase)
    var opposite_stride := sin(phase + PI)
    var bob := (0.5 - 0.5 * cos(phase * 2.0)) * 0.35 * blend

    var pelvis := Vector2(0.0, -49.0 + bob)
    var chest := Vector2(-stride * 0.18 * blend, -82.0 + bob)
    var neck := chest + Vector2(0.0, -7.0)
    var head := neck + Vector2(0.0, -13.0)

    var near_hip := pelvis + Vector2(2.0, 0.0)
    var far_hip := pelvis + Vector2(-2.0, 0.6)

    # Opposing feet move through a small arc; swing lift is smooth and limited.
    var near_lift := pow(maxf(0.0, stride), 1.5) * STEP_LIFT * blend
    var far_lift := pow(maxf(0.0, opposite_stride), 1.5) * STEP_LIFT * blend
    var near_ankle := Vector2(stride * STEP_REACH + 1.5, FOOT_REST_Y - near_lift)
    var far_ankle := Vector2(opposite_stride * STEP_REACH - 1.5, FOOT_REST_Y - far_lift)

    # Both knees bend forward in the walking direction, with subtle depth offset.
    var near_knee := _solve_knee(near_hip, near_ankle, -1.0)
    var far_knee := _solve_knee(far_hip, far_ankle, 1.0)

    var left_shoulder := chest + Vector2(-7.0, 1.0)
    var right_shoulder := chest + Vector2(7.0, 1.0)
    var arm_swing := stride * 2.0 * blend
    var left_elbow := left_shoulder + Vector2(-0.4 - arm_swing * 0.25, 11.5)
    var right_elbow := right_shoulder + Vector2(0.4 + arm_swing * 0.25, 11.5)
    var left_hand := left_elbow + Vector2(-arm_swing * 0.55, 10.5)
    var right_hand := right_elbow + Vector2(arm_swing * 0.55, 10.5)

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
    var raw_distance := delta.length()
    var min_distance := absf(THIGH_LENGTH - CALF_LENGTH) + 0.01
    var max_distance := THIGH_LENGTH + CALF_LENGTH - 0.01
    var distance := clampf(raw_distance, min_distance, max_distance)
    var direction := delta / maxf(raw_distance, 0.001)
    var along := (THIGH_LENGTH * THIGH_LENGTH - CALF_LENGTH * CALF_LENGTH + distance * distance) / (2.0 * distance)
    var height := sqrt(maxf(0.0, THIGH_LENGTH * THIGH_LENGTH - along * along))
    return hip + direction * along + Vector2(-direction.y, direction.x) * bend_side * height
