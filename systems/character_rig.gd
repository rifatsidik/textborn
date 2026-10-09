extends RefCounted
class_name TextbornCharacterRig

# Procedural 2D character rig. All dimensions are in world pixels.
# Walk uses explicit stance/swing phases instead of a free-running sine wave.
const HIP_Y := -48.0
const CHEST_Y := -79.0
const HEAD_Y := -111.0
const THIGH := 22.0
const SHIN := 23.0
const STEP_LENGTH := 18.0
const STEP_HEIGHT := 5.0
const STANCE_FRACTION := 0.62

func build_pose(gait: float, blend: float) -> Dictionary:
    var phase := fposmod(gait / TAU, 1.0)
    var bob := (0.5 - 0.5 * cos(gait * 2.0)) * 0.8 * blend
    var pelvis := Vector2(0.0, HIP_Y + bob)
    var chest := Vector2(-sin(gait) * 0.7 * blend, CHEST_Y + bob)
    var neck := chest + Vector2(0.0, -6.0)
    var head := Vector2(0.0, HEAD_Y + bob)

    # Near/far hips are close together in a side-on view, not spread laterally.
    var near_hip := pelvis + Vector2(2.0, 0.0)
    var far_hip := pelvis + Vector2(-1.8, 0.8)
    var near_foot := _foot_target(phase, blend, 1.0)
    var far_foot := _foot_target(fposmod(phase + 0.5, 1.0), blend, -1.0)
    var near_ankle := near_foot + Vector2(2.0, 0.0)
    var far_ankle := far_foot + Vector2(-1.5, 0.8)

    var near_knee := _knee(near_hip, near_ankle, 1.0, phase, blend)
    var far_knee := _knee(far_hip, far_ankle, -1.0, fposmod(phase + 0.5, 1.0), blend)

    var left_shoulder := chest + Vector2(-6.5, 1.0)
    var right_shoulder := chest + Vector2(6.5, 1.0)
    var swing := sin(gait) * 3.0 * blend
    var left_elbow := left_shoulder + Vector2(-0.6 - swing * 0.25, 11.0)
    var right_elbow := right_shoulder + Vector2(0.6 + swing * 0.25, 11.0)
    var left_hand := left_elbow + Vector2(-swing * 0.65, 10.0)
    var right_hand := right_elbow + Vector2(swing * 0.65, 10.0)

    return {
        "head": head, "neck": neck, "chest": chest, "pelvis": pelvis,
        "left_shoulder": left_shoulder, "right_shoulder": right_shoulder,
        "left_elbow": left_elbow, "right_elbow": right_elbow,
        "left_hand": left_hand, "right_hand": right_hand,
        "left_hip": far_hip, "right_hip": near_hip,
        "left_knee": far_knee, "right_knee": near_knee,
        "left_ankle": far_ankle, "right_ankle": near_ankle,
        "left_foot": far_foot, "right_foot": near_foot
    }

func _foot_target(phase: float, blend: float, side: float) -> Vector2:
    var x: float
    var lift := 0.0
    if phase < STANCE_FRACTION:
        # Foot moves backward relative to body while planted on the ground.
        var t := phase / STANCE_FRACTION
        x = lerpf(STEP_LENGTH * 0.5, -STEP_LENGTH * 0.5, t)
    else:
        # Quick smooth swing forward, with a controlled toe clearance arc.
        var t := (phase - STANCE_FRACTION) / (1.0 - STANCE_FRACTION)
        var smooth := t * t * (3.0 - 2.0 * t)
        x = lerpf(-STEP_LENGTH * 0.5, STEP_LENGTH * 0.5, smooth)
        lift = sin(PI * t) * STEP_HEIGHT
    return Vector2(x * blend, -lift * blend)

func _knee(hip: Vector2, ankle: Vector2, side: float, phase: float, blend: float) -> Vector2:
    var mid := hip.lerp(ankle, 0.52)
    var swing_phase := fposmod(phase - STANCE_FRACTION, 1.0 - STANCE_FRACTION) / (1.0 - STANCE_FRACTION)
    var bend := 1.0 if phase >= STANCE_FRACTION else 0.0
    # Knees flex forward only in swing; slight far-side offset provides depth.
    var forward := (2.0 + sin(swing_phase * PI) * 4.0) * bend * blend
    return Vector2(mid.x + forward + side * 0.7, mid.y - bend * 1.0)
