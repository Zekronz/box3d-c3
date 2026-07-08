/*
	https://github.com/erincatto/box3d

	MIT License

	Copyright (c) 2026 Erin Catto

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
*/

/*
	C3 bindings for Box3D, by Zekronz.

	Feature flags: BOX3D_ENABLE_ASSERT, BOX3D_ENABLE_VALIDATION, BOX3D_DOUBLE_PRECISION
*/

module box3d;
import std::math;

//BASE
const NULL_INDEX = -1;

alias AllocFcn = fn void* (int size, int alignment);
alias FreeFcn = fn void (void *mem);
alias AssertFcn = fn int (ZString condition, ZString fileName, int lineNumber);
alias LogFcn = fn void (ZString message);

extern fn void setAllocator(AllocFcn allocFcn, FreeFcn freeFcn) @cname("b3SetAllocator");
extern fn int getByteCount() @cname("b3GetByteCount");
extern fn void setAssertFcn(AssertFcn assertFcn) @cname("b3SetAssertFcn");

extern fn int internalAssert(ZString condition, ZString fileName, int lineNumber) @cname("b3InternalAssert");

macro @assert(bool #condition) => @pool() {
	$if $feature(BOX3D_ENABLE_ASSERT):
		bool val = #condition;
		if(@unlikely(!val)){
			String expr = $stringify(#condition);
			internalAssert(expr.zstr_tcopy(), $$FILE.zstr_tcopy(), (int)$$LINE);
		}
	$endif
}

macro @validate(bool #condition) => @pool() {
	$if $feature(BOX3D_ENABLE_VALIDATION):
		bool val = #condition;
		if(@unlikely(!val)){
			String expr = $stringify(#condition);
			internalAssert(expr.zstr_tcopy(), $$FILE.zstr_tcopy(), $$LINE);
		}
	$endif
}

extern fn void setLogFcn(LogFcn logFcn) @cname("b3SetLogFcn");

struct Version {
	int major;
	int minor;
	int revision;
}

extern fn Version getVersion() @cname("b3GetVersion");

extern fn bool isDoublePrecision() @cname("b3IsDoublePrecision");
extern fn ulong getTicks() @cname("b3GetTicks");
extern fn float getMilliseconds(ulong ticks) @cname("b3GetMilliseconds");
extern fn float getMillisecondsAndReset(ulong *ticks) @cname("b3GetMillisecondsAndReset");
extern fn void yield() @cname("b3Yield");
extern fn void sleep(int milliseconds) @cname("b3Sleep");

const HASH_INIT = 5381;
extern fn uint hash(uint hash, char *data, int count) @cname("b3Hash");


//ID
struct WorldId {
	ushort index1;
	ushort generation;
}

struct BodyId {
	int index1;
	ushort world0;
	ushort generation;
}

struct ShapeId {
	int index1;
	ushort world0;
	ushort generation;
}

struct JointId {
	int index1;
	ushort world0;
	ushort generation;
}

struct ContactId {
	int index1;
	ushort world0;
	short padding;
	uint generation;
}

//C3 zero-initializes by default so these are kinda pointless:
const WorldId NULL_WORLD_ID = {};
const BodyId NULL_BODY_ID = {};
const ShapeId NULL_SHAPE_ID = {};
const JointId NULL_JOINT_ID = {};
const ContactId NULL_CONTACT_ID = {};

macro bool is_null(id){
	return (id.index1 == 0);
}

macro bool is_non_null(id){
	return (id.index1 != 0);
}

macro bool id_equals(id1, id2){
	return (id1.index1 == id2.index1 && id1.world0 == id2.world0 && id1.generation == id2.generation);
}

fn uint storeWorldId(WorldId id) @inline {
	return ((uint)id.index1 << 16) | (uint)id.generation;
}

fn WorldId loadWorldId(uint x) @inline {
	WorldId id = { (ushort)(x >> 16), (ushort)(x) };
	return id;
}

fn ulong storeBodyId(BodyId id) @inline {
	return ((ulong)id.index1 << 32) | ((ulong)id.world0) << 16 | (ulong)id.generation;
}

fn BodyId loadBodyId(ulong x) @inline {
	BodyId id = { (int)(x >> 32), (ushort)(x >> 16), (ushort)(x) };
	return id;
}

fn ulong storeShapeId(ShapeId id) @inline {
	return ((ulong)id.index1 << 32) | ((ulong)id.world0) << 16 | (ulong)id.generation;
}

fn ShapeId loadShapeId(ulong x) @inline {
	ShapeId id = { (int)(x >> 32), (ushort)(x >> 16), (ushort)(x) };
	return id;
}

fn ulong storeJointId(JointId id) @inline {
	return ((ulong)id.index1 << 32) | ((ulong)id.world0) << 16 | (ulong)id.generation;
}

fn JointId loadJointId(ulong x) @inline {
	JointId id = { (int)(x >> 32), (ushort)(x >> 16), (ushort)(x) };
	return id;
}

fn void storeContactId(ContactId id, uint[3] *values) @inline {
	(*values)[0] = (uint)id.index1;
	(*values)[1] = (uint)id.world0;
	(*values)[2] = (uint)id.generation;
}

fn ContactId loadContactId(uint[3] values) @inline {
	ContactId id;
	id.index1 = (int)values[0];
	id.world0 = (ushort)values[1];
	id.padding = 0;
	id.generation = (uint)values[2];
	return id;
}


//MATH
//@TODO: Non-libc implementations:
extern fn float remainderf(float x, float y) @local @MathLibc("remainderf") @if(env::LIBC);
extern fn float nextafterf(float x, float y) @local @MathLibc("nextafterf") @if(env::LIBC);

const FLT_MIN @local = 1.17549435e-38f;
const FLT_MAX @local = 3.402823466e+38f;
const FLT_EPSILON @local = 1.19209290e-07f;

const float PI = 3.14159265359f;
const float DEG_TO_RAD = 0.01745329251f;
const float RAD_TO_DEG = 57.2957795131f;
const float MIN_SCALE = 0.01f;

struct Vec2 {
	float x;
	float y;
}

struct Vec3 {
	float x;
	float y;
	float z;
}

struct CosSin {
	float cosine;
	float sine;
}

struct Quat {
	Vec3 v;
	float s;
}

struct Transform {
	Vec3 p;
	Quat q;
}

struct PosD {
	double x, y, z;
}

struct WorldTransformD {
	PosD p;
	Quat q;
}

alias Pos @if($feature(BOX3D_DOUBLE_PRECISION)) = PosD;
alias Pos @if(!$feature(BOX3D_DOUBLE_PRECISION)) = Vec3;

alias WorldTransform @if($feature(BOX3D_DOUBLE_PRECISION)) = WorldTransformD;
alias WorldTransform @if(!$feature(BOX3D_DOUBLE_PRECISION)) = Transform;

struct Matrix3 {
	Vec3 cx, cy, cz;
}

struct Aabb {
	Vec3 lowerBound;
	Vec3 upperBound;
}

struct Plane {
	Vec3 normal;
	float offset;
}

const Vec3 VEC3_ZERO = { 0.0f, 0.0f, 0.0f };
const Vec3 VEC3_ONE = { 1.0f, 1.0f, 1.0f };
const Vec3 VEC3_AXIS_X = { 1.0f, 0.0f, 0.0f };
const Vec3 VEC3_AXIS_Y = { 0.0f, 1.0f, 0.0f };
const Vec3 VEC3_AXIS_Z = { 0.0f, 0.0f, 1.0f };
const Quat QUAT_IDENTITY = { { 0.0f, 0.0f, 0.0f }, 1.0f };
const Transform TRANSFORM_IDENTITY = { { 0.0f, 0.0f, 0.0f }, { { 0.0f, 0.0f, 0.0f }, 1.0f } };
const Matrix3 MAT3_ZERO = { { 0.0f, 0.0f, 0.0f }, { 0.0f, 0.0f, 0.0f }, { 0.0f, 0.0f, 0.0f } };
const Matrix3 MAT3_IDENTITY = { { 1.0f, 0.0f, 0.0f }, { 0.0f, 1.0f, 0.0f }, { 0.0f, 0.0f, 1.0f } };
const Pos POS_ZERO = { 0.0f, 0.0f, 0.0f };
const WorldTransform WORLD_TRANSFORM_IDENTITY = { { 0.0f, 0.0f, 0.0f }, { { 0.0f, 0.0f, 0.0f }, 1.0f } };

fn int minInt(int a, int b) @inline {
	return a < b ? a : b;
}

fn int maxInt(int a, int b) @inline {
	return a > b ? a : b;
}

fn int clampInt(int a, int lower, int upper) @inline {
	return a < lower ? lower : (upper < a ? upper : a);
}

fn float absFloat(float a) @inline {
	return a < 0 ? -a : a;
}

fn float minFloat(float a, float b) @inline {
	return a < b ? a : b;
}

fn float maxFloat(float a, float b) @inline {
	return a > b ? a : b;
}

fn float clampFloat(float a, float lower, float upper) @inline {
	return a < lower ? lower : (upper < a ? upper : a);
}

fn float lerpFloat(float a, float b, float alpha) @inline {
	return (1.0f - alpha) * a + alpha * b;
}

extern fn float atan2(float y, float x) @cname("b3Atan2");
extern fn CosSin computeCosSin(float radians) @cname("b3ComputeCosSin");

fn float sin(float radians) @inline @deprecated {
	CosSin cs = computeCosSin(radians);
	return cs.sine;
}

fn float cos(float radians) @inline @deprecated {
	CosSin cs = computeCosSin(radians);
	return cs.cosine;
}

fn float unwindAngle(float radians) @inline {
	return remainderf(radians, 2.0f * PI);
}

fn Vec3 add(Vec3 a, Vec3 b) @inline {
	return { a.x + b.x, a.y + b.y, a.z + b.z };
}

fn Vec3 sub(Vec3 a, Vec3 b) @inline {
	return { a.x - b.x, a.y - b.y, a.z - b.z };
}

fn Vec3 mul(Vec3 a, Vec3 b) @inline {
	return { a.x * b.x, a.y * b.y, a.z * b.z };
}

fn Vec3 neg(Vec3 a) @inline {
	return { -a.x, -a.y, -a.z };
}

fn float dot(Vec3 a, Vec3 b) @inline {
	return a.x * b.x + a.y * b.y + a.z * b.z;
}

fn float length(Vec3 v) @inline {
	return math::sqrt(dot(v, v));
}

fn float lengthSquared(Vec3 a) @inline {
	return a.x * a.x + a.y * a.y + a.z * a.z;
}

fn float distance(Vec3 a, Vec3 b) @inline {
	Vec3 dv = { b.x - a.x, b.y - a.y, b.z - a.z };
	return length(dv);
}

fn float distanceSquared(Vec3 a, Vec3 b) @inline {
	Vec3 dv = { b.x - a.x, b.y - a.y, b.z - a.z };
	return dv.x * dv.x + dv.y * dv.y + dv.z * dv.z;
}

fn Vec3 normalize(Vec3 a) @inline {
	float lengthSquared = a.x * a.x + a.y * a.y + a.z * a.z;

	if(lengthSquared > 1000.0f * FLT_MIN){
		float s = 1.0f / math::sqrt(lengthSquared);
		Vec3 u = { s * a.x, s * a.y, s * a.z };
		return u;
	}

	return { 0.0f, 0.0f, 0.0f };
}

fn Vec3 getLengthAndNormalize(float *len, Vec3 a) @inline {
	*len = length(a);
	if ((*len) < FLT_EPSILON) return VEC3_ZERO;

	float invLength = 1.0f / (*len);
	Vec3 n = { invLength * a.x, invLength * a.y, invLength * a.z };
	return n;
}

fn Vec3 perp(Vec3 a) @inline {
	Vec3 p;
	if (a.x < -0.5f || 0.5f < a.x){
		p = { a.y, -a.x, 0.0f };
	}else{
		p = { 0.0f, a.z, -a.y };
	}

	return normalize(p);
}

fn bool isNormalized(Vec3 a) @inline {
	float aa = dot(a, a);
	return absFloat(1.0f - aa) < 100.0f * FLT_EPSILON;
}

fn Vec3 mulAdd(Vec3 a, float s, Vec3 b) @inline {
	return { a.x + s * b.x, a.y + s * b.y, a.z + s * b.z };
}

fn Vec3 mulSub(Vec3 a, float s, Vec3 b) @inline {
	return { a.x - s * b.x, a.y - s * b.y, a.z - s * b.z };
}

fn Vec3 mulSV(float s, Vec3 a) @inline {
	return { s * a.x, s * a.y, s * a.z };
}

fn Vec3 mulVS(Vec3 a, float s) @inline {
	return { s * a.x, s * a.y, s * a.z };
}

fn Vec3 cross(Vec3 a, Vec3 b) @inline {
	Vec3 c;
	c.x = a.y * b.z - a.z * b.y;
	c.y = a.z * b.x - a.x * b.z;
	c.z = a.x * b.y - a.y * b.x;
	return c;
}

fn Vec3 lerp(Vec3 a, Vec3 b, float alpha) @inline {
	@assert(0.0f <= alpha && alpha <= 1.0f);

	Vec3 c = {
		(1.0f - alpha) * a.x + alpha * b.x,
		(1.0f - alpha) * a.y + alpha * b.y,
		(1.0f - alpha) * a.z + alpha * b.z,
	};
	return c;
}

fn Vec3 blend2(float s, Vec3 a, float t, Vec3 b) @inline {
	Vec3 d = {
		s * a.x + t * b.x,
		s * a.y + t * b.y,
		s * a.z + t * b.z,
	};
	return d;
}

fn Vec3 abs(Vec3 a) @inline {
	return { absFloat(a.x), absFloat(a.y), absFloat(a.z) };
}

fn Vec3 sign(Vec3 a) @inline {
	return { a.x >= 0.0f ? 1.0f : -1.0f, a.y >= 0.0f ? 1.0f : -1.0f, a.z >= 0.0f ? 1.0f : -1.0f };
}

fn Vec3 min(Vec3 a, Vec3 b) @inline {
	return { minFloat(a.x, b.x), minFloat(a.y, b.y), minFloat(a.z, b.z) };
}

fn Vec3 max(Vec3 a, Vec3 b) @inline {
	return { maxFloat(a.x, b.x), maxFloat(a.y, b.y), maxFloat(a.z, b.z) };
}

fn Vec3 clamp(Vec3 a, Vec3 lower, Vec3 upper) @inline {
	Vec3 b;
	b.x = clampFloat(a.x, lower.x, upper.x);
	b.y = clampFloat(a.y, lower.y, upper.y);
	b.z = clampFloat(a.z, lower.z, upper.z);
	return b;
}

fn Vec3 safeScale(Vec3 a) @inline {
	Vec3 absScale = abs(a);
	Vec3 minScale = { MIN_SCALE, MIN_SCALE, MIN_SCALE };
	Vec3 safeScale = mul(sign(a), max(absScale, minScale));
	return safeScale;
}

fn bool isNormalizedQuat(Quat q) @inline {
	float qq = q.v.x * q.v.x + q.v.y * q.v.y + q.v.z * q.v.z + q.s * q.s;
	return 1.0f - 20.0f * FLT_EPSILON < qq && qq < 1.0f + 20.0f * FLT_EPSILON;
}

fn Vec3 rotateVector(Quat q, Vec3 v) @inline {
	Vec3 t1 = cross(q.v, v);
	Vec3 t2 = mulAdd(t1, q.s, v);
	Vec3 t3 = cross(q.v, t2);
	return mulAdd(v, 2.0f, t3);
}

fn Vec3 invRotateVector(Quat q, Vec3 v) @inline {
	Vec3 t1 = cross(q.v, v);
	Vec3 t2 = mulSub(t1, q.s, v);
	Vec3 t3 = cross(q.v, t2);
	return mulAdd(v, 2.0f, t3);
}

fn float dotQuat(Quat a, Quat b) @inline {
	return a.v.x * b.v.x + a.v.y * b.v.y + a.v.z * b.v.z + a.s * b.s;
}

fn Quat mulQuat(Quat q1, Quat q2) @inline {
	Vec3 t1 = cross(q1.v, q2.v);
	Vec3 t2 = mulAdd(t1, q1.s, q2.v);
	Vec3 t3 = mulAdd(t2, q2.s, q1.v);
	Quat q = { t3, q1.s * q2.s - dot(q1.v, q2.v) };
	return q;
}

fn Quat invMulQuat(Quat q1, Quat q2) @inline {
	Vec3 t1 = cross(q2.v, q1.v);
	Vec3 t2 = mulAdd(t1, q1.s, q2.v);
	Vec3 t3 = mulSub(t2, q2.s, q1.v);
	Quat q = { t3, q1.s * q2.s + dot(q1.v, q2.v) };
	return q;
}

fn Quat conjugate(Quat q) @inline {
	return { { -q.v.x, -q.v.y, -q.v.z }, q.s };
}

fn Quat negateQuat(Quat q) @inline {
	return { { -q.v.x, -q.v.y, -q.v.z }, -q.s };
}

fn Quat normalizeQuat(Quat q) @inline {
	float lengthSq = dotQuat(q, q);
	if (lengthSq > 1000.0f * FLT_MIN){
		float s = 1.0f / math::sqrt(lengthSq);
		Quat qn = { { s * q.v.x, s * q.v.y, s * q.v.z }, s * q.s };
		return qn;
	}

	return QUAT_IDENTITY;
}

fn Quat makeQuatFromAxisAngle(Vec3 axis, float radians) @inline {
	@assert(isNormalized(axis));
	CosSin cs = computeCosSin(0.5f * radians);
	Quat q = { { cs.sine * axis.x, cs.sine * axis.y, cs.sine * axis.z }, cs.cosine };
	return q;
}

fn Vec3 getAxisAngle(float *radians, Quat q) @inline {
	float length = math::sqrt(q.v.x * q.v.x + q.v.y * q.v.y + q.v.z * q.v.z);
	(*radians) = 2.0f * atan2(length, q.s);
	if (length > 0.0f) {
		float invLength = 1.0f / length;
		Vec3 axis = { invLength * q.v.x, invLength * q.v.y, invLength * q.v.z };
		return axis;
	}

	return VEC3_ZERO;
}

fn float getQuatAngle(Quat q) @inline {
	float length = math::sqrt(q.v.x * q.v.x + q.v.y * q.v.y + q.v.z * q.v.z);
	return 2.0f * atan2(length, q.s);
}

extern fn Quat makeQuatFromMatrix(Matrix3 *m) @cname("b3MakeQuatFromMatrix");
extern fn Quat computeQuatBetweenUnitVectors(Vec3 v1, Vec3 v2) @cname("b3ComputeQuatBetweenUnitVectors");

fn float getTwistAngle(Quat q) @inline {
	float twist = q.s < 0.0f ? atan2(-q.v.z, -q.s) : atan2(q.v.z, q.s);
	twist *= 2.0f;
	@assert(-PI <= twist && twist <= PI);
	return twist;
}

fn float getSwingAngle(Quat q) @inline {
	float x = math::sqrt(q.v.z * q.v.z + q.s * q.s);
	float y = math::sqrt(q.v.x * q.v.x + q.v.y * q.v.y);
	float swing = 2.0f * atan2(y, x);
	@assert(0.0f <= swing && swing <= PI);
	return swing;
}

fn Quat nLerp(Quat q1, Quat q2, float alpha) @inline {
	@validate(0.0f <= alpha && alpha <= 1.0f);
	if (dotQuat(q1, q2) < 0.0f){
		q1 = { { -q1.v.x, -q1.v.y, -q1.v.z }, -q1.s };
	}

	Quat q;
	q.v = lerp(q1.v, q2.v, alpha);
	q.s = (1.0f - alpha) * q1.s + alpha * q2.s;

	return normalizeQuat(q);
}

fn Transform mulTransforms(Transform a, Transform b) @inline {
	Transform out;
	out.p = add(rotateVector(a.q, b.p), a.p);
	out.q = mulQuat(a.q, b.q);
	return out;
}

fn Transform invMulTransforms(Transform a, Transform b) @inline {
	Transform out;
	out.p = invRotateVector(a.q, sub(b.p, a.p));
	out.q = invMulQuat(a.q, b.q);
	return out;
}

fn Transform invertTransform(Transform t) @inline {
	Transform out;
	out.p = invRotateVector(t.q, neg(t.p));
	out.q = conjugate(t.q);
	return out;
}

fn Vec3 transformPoint(Transform t, Vec3 v) @inline {
	Vec3 rv = rotateVector(t.q, v);
	return add(rv, t.p);
}

fn Vec3 invtransformPoint(Transform t, Vec3 v) @inline {
	return invRotateVector(t.q, sub(v, t.p));
}

fn Pos toPos(Vec3 v) @inline {
	return { v.x, v.y, v.z };
}

fn Vec3 toVec3(Pos p) @inline {
	return { (float)p.x, (float)p.y, (float)p.z };
}

fn float roundDownFloat(double x) @inline {
	$if $feature(BOX3D_DOUBLE_PRECISION):
		float f = (float)x;
		return (double)f > x ? nextafterf(f, -FLT_MAX) : f;
	$else
		return (float)x;
	$endif
}

fn float roundUpFloat(double x) @inline {
	$if $feature(BOX3D_DOUBLE_PRECISION):
		float f = (float)x;
		return (double)f < x ? nextafterf(f, FLT_MAX) : f;
	$else
		return (float)x;
	$endif
}

fn Vec3 subPos(Pos a, Pos b) @inline {
	return { (float)(a.x - b.x), (float)(a.y - b.y), (float)(a.z - b.z) };
}

fn Pos offsetPos(Pos p, Vec3 d) @inline {
	return { p.x + d.x, p.y + d.y, p.z + d.z };
}

fn Pos lerpPosition(Pos a, Pos b, float t) @inline {
	$if $feature(BOX3D_DOUBLE_PRECISION):
		return { (double)(1.0f - t) * a.x + t * b.x, (double)(1.0f - t) * a.y + t * b.y, (double)(1.0f - t) * a.z + t * b.z };
	$else
		return { (1.0f - t) * a.x + t * b.x, (1.0f - t) * a.y + t * b.y, (1.0f - t) * a.z + t * b.z };
	$endif
}

fn Pos transformWorldPoint(WorldTransform t, Vec3 p) @inline {
	Vec3 r = rotateVector(t.q, p);
	return { t.p.x + r.x, t.p.y + r.y, t.p.z + r.z };
}

fn Vec3 invTransformWorldPoint(WorldTransform t, Pos p) @inline {
	Vec3 d = { (float)(p.x - t.p.x), (float)(p.y - t.p.y), (float)(p.z - t.p.z) };
	return invRotateVector(t.q, d);
}

fn Transform invMulWorldTransforms(WorldTransform a, WorldTransform b) @inline {
	Transform c;
	c.q = invMulQuat(a.q, b.q);
	Vec3 d = { (float)(b.p.x - a.p.x), (float)(b.p.y - a.p.y), (float)(b.p.z - a.p.z) };
	c.p = invRotateVector(a.q, d);
	return c;
}

fn WorldTransform mulWorldTransforms(WorldTransform a, Transform b) @inline {
	WorldTransform c;
	c.q = mulQuat(a.q, b.q);
	Vec3 r = rotateVector(a.q, b.p);
	c.p = { a.p.x + r.x, a.p.y + r.y, a.p.z + r.z };
	return c;
}

fn Transform toRelativeTransform(WorldTransform t, Pos base) @inline {
	Transform r;
	r.q = t.q;
	r.p = { (float)(t.p.x - base.x), (float)(t.p.y - base.y), (float)(t.p.z - base.z) };
	return r;
}

fn WorldTransform makeWorldTransform(Transform t) @inline {
	WorldTransform w;
	w.p = toPos(t.p);
	w.q = t.q;
	return w;
}

fn Aabb offsetAABB(Aabb localBox, Pos origin) @inline {
	Aabb out;
	out.lowerBound.x = roundDownFloat(origin.x + (double)localBox.lowerBound.x);
	out.lowerBound.y = roundDownFloat(origin.y + (double)localBox.lowerBound.y);
	out.lowerBound.z = roundDownFloat(origin.z + (double)localBox.lowerBound.z);
	out.upperBound.x = roundUpFloat(origin.x + (double)localBox.upperBound.x);
	out.upperBound.y = roundUpFloat(origin.y + (double)localBox.upperBound.y);
	out.upperBound.z = roundUpFloat(origin.z + (double)localBox.upperBound.z);
	return out;
}

fn float det(Matrix3 m) @inline {
	return dot(m.cx, cross(m.cy, m.cz));
}

fn Vec3 mulMV(Matrix3 m, Vec3 a) @inline {
	Vec3 b = {
		m.cx.x * a.x + m.cy.x * a.y + m.cz.x * a.z,
		m.cx.y * a.x + m.cy.y * a.y + m.cz.y * a.z,
		m.cx.z * a.x + m.cy.z * a.y + m.cz.z * a.z
	};
	return b;
}

fn Matrix3 negateMat3(Matrix3 a) @inline {
	return {
		{ -a.cx.x, -a.cx.y, -a.cx.z },
		{ -a.cy.x, -a.cy.y, -a.cy.z },
		{ -a.cz.x, -a.cz.y, -a.cz.z }
	};
}

fn Matrix3 addMM(Matrix3 a, Matrix3 b) @inline {
	return {
		{ a.cx.x + b.cx.x, a.cx.y + b.cx.y, a.cx.z + b.cx.z },
		{ a.cy.x + b.cy.x, a.cy.y + b.cy.y, a.cy.z + b.cy.z },
		{ a.cz.x + b.cz.x, a.cz.y + b.cz.y, a.cz.z + b.cz.z }
	};
}

fn Matrix3 subMM(Matrix3 a, Matrix3 b) @inline {
	return {
		{ a.cx.x - b.cx.x, a.cx.y - b.cx.y, a.cx.z - b.cx.z },
		{ a.cy.x - b.cy.x, a.cy.y - b.cy.y, a.cy.z - b.cy.z },
		{ a.cz.x - b.cz.x, a.cz.y - b.cz.y, a.cz.z - b.cz.z }
	};
}

fn Matrix3 mulSM(float s, Matrix3 a) @inline {
	return {
		{ s * a.cx.x, s * a.cx.y, s * a.cx.z },
		{ s * a.cy.x, s * a.cy.y, s * a.cy.z },
		{ s * a.cz.x, s * a.cz.y, s * a.cz.z }
	};
}

fn Matrix3 mulMM(Matrix3 a, Matrix3 b) @inline {
	Matrix3 out;
	out.cx = mulMV(a, b.cx);
	out.cy = mulMV(a, b.cy);
	out.cz = mulMV(a, b.cz);
	return out;
}

fn Matrix3 transpose(Matrix3 m) @inline {
	Matrix3 out;
	out.cx = { m.cx.x, m.cy.x, m.cz.x };
	out.cy = { m.cx.y, m.cy.y, m.cz.y };
	out.cz = { m.cx.z, m.cy.z, m.cz.z };
	return out;
}

fn Matrix3 invertMatrix(Matrix3 m) @inline {
	float d = det(m);
	if(absFloat(d) > 1000.0f * FLT_MIN){
		float invDet = 1.0f / d;
		Matrix3 out;
		out.cx = mulSV(invDet, cross(m.cy, m.cz));
		out.cy = mulSV(invDet, cross(m.cz, m.cx));
		out.cz = mulSV(invDet, cross(m.cx, m.cy));

		return transpose(out);
	}

	return MAT3_ZERO;
}

fn Vec3 solve3(Matrix3 m, Vec3 a) @inline {
	float d = det(m);
	if(absFloat(d) > 1000.0f * FLT_MIN){
		float invDet = 1.0f / d;
		Matrix3 s;
		s.cx = cross(m.cy, m.cz);
		s.cy = cross(m.cz, m.cx);
		s.cz = cross(m.cx, m.cy);

		Vec3 b = {
			invDet * dot(s.cx, a),
			invDet * dot(s.cy, a),
			invDet * dot(s.cz, a),
		};

		return b;
	}

	return VEC3_ZERO;
}

fn Matrix3 invertT(Matrix3 m) @inline {
	float d = det(m);
	if(absFloat(d) > 1000.0f * FLT_MIN){
		float invDet = 1.0f / d;
		Matrix3 out;
		out.cx = mulSV(invDet, cross(m.cy, m.cz));
		out.cy = mulSV(invDet, cross(m.cz, m.cx));
		out.cz = mulSV(invDet, cross(m.cx, m.cy));
		return out;
	}

	return MAT3_ZERO;
}

fn Matrix3 absMatrix3(Matrix3 m) @inline {
	Matrix3 out;
	out.cx = abs(m.cx);
	out.cy = abs(m.cy);
	out.cz = abs(m.cz);
	return out;
}

fn Matrix3 makeMatrixFromQuat(Quat q) @inline {
	float xx = q.v.x * q.v.x;
	float yy = q.v.y * q.v.y;
	float zz = q.v.z * q.v.z;
	float xy = q.v.x * q.v.y;
	float xz = q.v.x * q.v.z;
	float xw = q.v.x * q.s;
	float yz = q.v.y * q.v.z;
	float yw = q.v.y * q.s;
	float zw = q.v.z * q.s;

	return {
		{ 1.0f - 2.0f * (yy + zz), 2.0f * (xy + zw), 2.0f * (xz - yw) },
		{ 2.0f * (xy - zw), 1.0f - 2.0f * (xx + zz), 2.0f * (yz + xw) },
		{ 2.0f * (xz + yw), 2.0f * (yz - xw), 1.0f - 2.0f * (xx + yy) }
	};
}

extern fn Matrix3 steiner(float mass, Vec3 origin) @cname("b3Steiner");

fn Aabb makeAABB(Vec3 *points, int count, float radius) @inline {
	@assert(count > 0);
	Aabb a = { points[0], points[0] };
	for(int i = 1; i < count; ++i){
		a.lowerBound = min(a.lowerBound, points[i]);
		a.upperBound = max(a.upperBound, points[i]);
	}

	Vec3 r = { radius, radius, radius };
	a.lowerBound = sub(a.lowerBound, r);
	a.upperBound = add(a.upperBound, r);

	return a;
}

fn bool aabb_Contains(Aabb a, Aabb b) @inline {
	if(a.lowerBound.x > b.lowerBound.x || b.upperBound.x > a.upperBound.x) return false;
	if(a.lowerBound.y > b.lowerBound.y || b.upperBound.y > a.upperBound.y) return false;
	if(a.lowerBound.z > b.lowerBound.z || b.upperBound.z > a.upperBound.z) return false;
	return true;
}

fn float aabb_Area(Aabb a) @inline {
	Vec3 delta = sub(a.upperBound, a.lowerBound);
	return 2.0f * (delta.x * delta.y + delta.y * delta.z + delta.z * delta.x);
}

fn Vec3 aabb_Center(Aabb a) @inline {
	return mulSV(0.5f, add(a.upperBound, a.lowerBound));
}

fn Vec3 aabb_Extents(Aabb a) @inline {
	return mulSV(0.5f, sub(a.upperBound, a.lowerBound));
}

fn Aabb aabb_Union(Aabb a, Aabb b) @inline {
	Aabb out;
	out.lowerBound = min(a.lowerBound, b.lowerBound);
	out.upperBound = max(a.upperBound, b.upperBound);
	return out;
}

fn Aabb aabb_Inflate(Aabb a, float extension) @inline {
	Vec3 radius = { extension, extension, extension };
	Aabb out;
	out.lowerBound = sub(a.lowerBound, radius);
	out.upperBound = add(a.upperBound, radius);
	return out;
}

fn bool aabb_Overlaps(Aabb a, Aabb b) @inline {
	if (a.upperBound.x < b.lowerBound.x || a.lowerBound.x > b.upperBound.x) return false;
	if (a.upperBound.y < b.lowerBound.y || a.lowerBound.y > b.upperBound.y) return false;
	if (a.upperBound.z < b.lowerBound.z || a.lowerBound.z > b.upperBound.z) return false;
	return true;
}

fn Aabb aabb_Transform(Transform transform, Aabb a) @inline {
	Vec3 center = transformPoint(transform, aabb_Center(a));
	Matrix3 m = makeMatrixFromQuat(transform.q);
	Vec3 extent = mulMV(absMatrix3(m), aabb_Extents(a));
	Aabb out = { sub(center, extent), add(center, extent) };
	return out;
}

fn Vec3 closestPointToAABB(Vec3 point, Aabb a) @inline {
	return clamp(point, a.lowerBound, a.upperBound);
}

struct SegmentDistanceResult {
	Vec3 point1;
	float fraction1;
	Vec3 point2;
	float fraction2;
}

extern fn Vec3 pointToSegmentDistance(Vec3 a, Vec3 b, Vec3 q) @cname("b3PointToSegmentDistance");
extern fn SegmentDistanceResult lineDistance(Vec3 p1, Vec3 d1, Vec3 p2, Vec3 d2) @cname("b3SegmentDistanceResult");
extern fn SegmentDistanceResult segmentDistance(Vec3 p1, Vec3 q1, Vec3 p2, Vec3 q2) @cname("b3SegmentDistanceResult");
extern fn bool isValidFloat(float a) @cname("b3IsValidFloat");
extern fn bool isValidVec3(Vec3 a) @cname("b3IsValidVec3");
extern fn bool isValidQuat(Quat q) @cname("b3IsValidQuat");
extern fn bool isValidTransform(Transform a) @cname("b3IsValidTransform");
extern fn bool isValidMatrix3(Matrix3 a) @cname("b3IsValidMatrix3");
extern fn bool isValidAABB(Aabb a) @cname("b3IsValidAABB");
extern fn bool isBoundedAABB(Aabb a) @cname("b3IsBoundedAABB");
extern fn bool isSaneAABB(Aabb a) @cname("b3IsSaneAABB");
extern fn bool isValidPlane(Plane a) @cname("b3IsValidPlane");
extern fn bool isValidPosition(Pos p) @cname("b3IsValidPosition");
extern fn bool isValidWorldTransform(WorldTransform t) @cname("b3IsValidWorldTransform");


//CONSTANTS
extern fn void setLengthUnitsPerMeter(float lengthUnits) @cname("b3SetLengthUnitsPerMeter");
extern fn float getLengthUnitsPerMeter() @cname("b3GetLengthUnitsPerMeter");
extern fn void setStallThreshold(float seconds) @cname("b3SetStallThreshold");
extern fn float getStallThreshold() @cname("b3GetStallThreshold");

macro huge(){
	$if $feature(BOX3D_DOUBLE_PRECISION):
		return (1.0e9f * GetLengthUnitsPerMeter());
	$else
		return (1.0e5f * GetLengthUnitsPerMeter());
	$endif
}

const MAX_WORKERS = 32;
const MAX_TASKS = 256;
const GRAPH_COLOR_COUNT = 24;
const CONTACT_MANIFOLD_COUNT_BUCKETS = 8;

macro linear_slop(){ return (0.005f * GetLengthUnitsPerMeter()); }
macro min_capsule_length(){ return linear_slop(); }
macro overlap_slop(){ return (0.1f * linear_slop()); }
macro speculative_distance(){ return (4.0f * linear_slop()); }
macro mesh_rest_offset(){ return (1.0f * linear_slop()); }
macro contact_recycle_distance(){ return (10.0f * linear_slop()); }

const MAX_WORLDS = 128;
const MAX_ROTATION = (0.25f * PI);
const CONTACT_RECYCLE_ANGULAR_DISTANCE = 0.99240388f;

macro max_aabb_margin(){
	return (0.05f * GetLengthUnitsPerMeter());
}

const AABB_MARGIN_FRACTION = 0.125f;
const TIME_TO_SLEEP = 0.5f;
const MAX_MANIFOLD_POINTS = 4;
const MAX_SHAPE_CAST_POINTS = 64;
const SHAPE_POWER = 22;
const CHILD_POWER = (64 - 2 * SHAPE_POWER);
const MAX_SHAPES = (1 << SHAPE_POWER);
const MAX_CHILD_SHAPES = (1 << CHILD_POWER);


//TYPES
const DEFAULT_CATEGORY_BITS = ulong::max;
const DEFAULT_MASK_BITS = ulong::max;

alias TaskCallback = fn void (void *taskContext);
alias EnqueueTaskCallback = fn void* (TaskCallback *task, void *taskContext, void *userContext, ZString taskName);
alias FinishTaskCallback = fn void (void *userTask, void *userContext);
alias CreateDebugShapeCallback = fn void* (DebugShape *debugShape, void *userContext);
alias DestroyDebugShapeCallback = fn void ( void* userShape, void* userContext);
alias FrictionCallback = fn float (float frictionA, ulong userMaterialIdA, float frictionB, ulong userMaterialIdB);
alias RestitutionCallback = fn float (float restitutionA, ulong userMaterialIdA, float restitutionB, ulong userMaterialIdB);
alias CustomFilterFcn = fn bool (ShapeId shapeIdA, ShapeId shapeIdB, void *context);
alias PreSolveFcn = fn bool (ShapeId shapeIdA, ShapeId shapeIdB, Pos point, Vec3 normal, void *context);
alias OverlapResultFcn = fn bool (ShapeId shapeId, void *context);
alias CastResultFcn = fn float (ShapeId shapeId, Pos point, Vec3 normal, float fraction, ulong userMaterialId, int triangleIndex, int childIndex, void *context);

struct Capacity{
	int staticShapeCount;
	int dynamicShapeCount;
	int staticBodyCount;
	int dynamicBodyCount;
	int contactCount;
}

struct WorldDef {
	Vec3 gravity;
	float restitutionThreshold;
	float hitEventThreshold;
	float contactHertz;
	float contactDampingRatio;
	float contactSpeed;
	float maximumLinearSpeed;
	FrictionCallback *frictionCallback;
	RestitutionCallback *restitutionCallback;
	bool enableSleep;
	bool enableContinuous;
	uint workerCount;
	EnqueueTaskCallback *enqueueTask;
	FinishTaskCallback *finishTask;
	void *userTaskContext;
	void *userData;
	CreateDebugShapeCallback *createDebugShape;
	DestroyDebugShapeCallback *destroyDebugShape;
	void *userDebugShapeContext;
	Capacity capacity;
	int internalValue;
}

extern fn WorldDef defaultWorldDef() @cname("b3DefaultWorldDef");

constdef BodyType {
	STATIC = 0,
	KINEMATIC = 1,
	DYNAMIC = 2,
	COUNT
}

struct MotionLocks {
	bool linearX;
	bool linearY;
	bool linearZ;
	bool angularX;
	bool angularY;
	bool angularZ;
}

struct BodyDef {
	BodyType type;
	Pos position;
	Quat rotation;
	Vec3 linearVelocity;
	Vec3 angularVelocity;
	float linearDamping;
	float angularDamping;
	float gravityScale;
	float sleepThreshold;
	ZString name;
	void *userData;
	MotionLocks motionLocks;
	bool enableSleep;
	bool isAwake;
	bool isBullet;
	bool isEnabled;
	bool allowFastRotation;
	bool enableContactRecycling;
	int internalValue;
}

extern fn BodyDef defaultBodyDef() @cname("b3DefaultBodyDef");

struct Filter {
	ulong categoryBits;
	ulong maskBits;
	int groupIndex;
}

extern fn Filter defaultFilter() @cname("b3DefaultFilter");

struct SurfaceMaterial {
	float friction;
	float restitution;
	float rollingResistance;
	Vec3 tangentVelocity;
	ulong userMaterialId;
	uint customColor;
}

extern fn SurfaceMaterial defaultSurfaceMaterial() @cname("b3DefaultSurfaceMaterial");

constdef ShapeType {
	CAPSULE,
	COMPOUND,
	HEIGHT,
	HULL,
	MESH,
	SHPERE,
	COUNT
}

struct ShapeDef {
	ZString name;
	void *userData;
	SurfaceMaterial *materials;
	int materialCount;
	SurfaceMaterial baseMaterial;
	float density;
	float explosionScale;
	Filter filter;
	bool enableCustomFiltering;
	bool isSensor;
	bool enableSensorEvents;
	bool enableContactEvents;
	bool enableHitEvents;
	bool enablePreSolveEvents;
	bool invokeContactCreation;
	bool updateBodyMass;
	int internalValue;
}

extern fn ShapeDef defaultShapeDef() @cname("b3DefaultShapeDef");

struct Profile {
	float step;
	float pairs;
	float collide;
	float solve;
	float solverSetup;
	float constraints;
	float prepareConstraints;
	float integrateVelocities;
	float warmStart;
	float solveImpulses;
	float integratePositions;
	float relaxImpulses;
	float applyRestitution;
	float storeImpulses;
	float splitIslands;
	float transforms;
	float sensorHits;
	float jointEvents;
	float hitEvents;
	float refit;
	float bullets;
	float sleepIslands;
	float sensors;
}

struct Counters {
	int bodyCount;
	int shapeCount;
	int contactCount;
	int jointCount;
	int islandCount;
	int stackUsed;
	int arenaCapacity;
	int staticTreeHeight;
	int treeHeight;
	int satCallCount;
	int satCacheHitCount;
	int byteCount;
	int taskCount;
	int[24] colorCounts;
	int[CONTACT_MANIFOLD_COUNT_BUCKETS] manifoldCounts;
	int awakeContactCount;
	int recycledContactCount;
	int distanceIterations;
	int pushBackIterations;
	int rootIterations;
}

constdef JointType {
	PARALLEL,
	DISTANCE,
	FILTER,
	MOTOR,
	PRISMATIC,
	REVOLUTE,
	SPERICAL,
	WELD,
	WHEEL,
}

struct JointDef {
	void *userData;
	BodyId bodyIdA;
	BodyId bodyIdB;
	Transform localFrameA;
	Transform localFrameB;
	float forceThreshold;
	float torqueThreshold;
	float constraintHertz;
	float constraintDampingRatio;
	float drawScale;
	bool collideConnected;
	int internalValue;
}

struct DistanceJointDef {
	JointDef base;
	float length;
	bool enableSpring;
	float lowerSpringForce;
	float upperSpringForce;
	float hertz;
	float dampingRatio;
	bool enableLimit;
	float minLength;
	float maxLength;
	bool enableMotor;
	float maxMotorForce;
	float motorSpeed;
}

extern fn DistanceJointDef defaultDistanceJointDef() @cname("b3DefaultDistanceJointDef");

struct MotorJointDef {
	JointDef base;
	Vec3 linearVelocity;
	float maxVelocityForce;
	Vec3 angularVelocity;
	float maxVelocityTorque;
	float linearHertz;
	float linearDampingRatio;
	float maxSpringForce;
	float angularHertz;
	float angularDampingRatio;
	float maxSpringTorque;
}

extern fn MotorJointDef defaultMotorJointDef() @cname("b3DefaultMotorJointDef");

struct FilterJointDef {
	JointDef base;
}

extern fn FilterJointDef defaultFilterJointDef() @cname("b3DefaultFilterJointDef");

struct ParallelJointDef {
	JointDef base;
	float hertz;
	float dampingRatio;
	float maxTorque;
}

extern fn ParallelJointDef defaultParallelJointDef() @cname("b3DefaultParallelJointDef");

struct PrismaticJointDef {
	JointDef base;
	bool enableSpring;
	float hertz;
	float dampingRatio;
	float targetTranslation;
	bool enableLimit;
	float lowerTranslation;
	float upperTranslation;
	bool enableMotor;
	float maxMotorForce;
	float motorSpeed;
}

extern fn PrismaticJointDef defaultPrismaticJointDef() @cname("b3DefaultPrismaticJointDef");

struct RevoluteJointDef {
	JointDef base;
	float targetAngle;
	bool enableSpring;
	float hertz;
	float dampingRatio;
	bool enableLimit;
	float lowerAngle;
	float upperAngle;
	bool enableMotor;
	float maxMotorTorque;
	float motorSpeed;
}

extern fn RevoluteJointDef defaultRevoluteJointDef() @cname("b3DefaultRevoluteJointDef");

struct SphericalJointDef {
	JointDef base;
	bool enableSpring;
	float hertz;
	float dampingRatio;
	Quat targetRotation;
	bool enableConeLimit;
	float coneAngle;
	bool enableTwistLimit;
	float lowerTwistAngle;
	float upperTwistAngle;
	bool enableMotor;
	float maxMotorTorque;
	Vec3 motorVelocity;
}

extern fn SphericalJointDef defaultSphericalJointDef() @cname("b3DefaultSphericalJointDef");

struct WeldJointDef {
	JointDef base;
	float linearHertz;
	float angularHertz;
	float linearDampingRatio;
	float angularDampingRatio;
}

extern fn WeldJointDef defaultWeldJointDef() @cname("b3DefaultWeldJointDef");

struct WheelJointDef {
	JointDef base;
	bool enableSuspensionSpring;
	float suspensionHertz;
	float suspensionDampingRatio;
	bool enableSuspensionLimit;
	float lowerSuspensionLimit;
	float upperSuspensionLimit;
	bool enableSpinMotor;
	float maxSpinTorque;
	float spinSpeed;
	bool enableSteering;
	float steeringHertz;
	float steeringDampingRatio;
	float targetSteeringAngle;
	float maxSteeringTorque;
	bool enableSteeringLimit;
	float lowerSteeringLimit;
	float upperSteeringLimit;
}

extern fn WheelJointDef defaultWheelJointDef() @cname("b3DefaultWheelJointDef");

struct ExplosionDef {
	ulong maskBits;
	Pos position;
	float radius;
	float falloff;
	float impulsePerArea;
}

extern fn ExplosionDef defaultExplosionDef() @cname("b3DefaultExplosionDef");

struct SensorBeginTouchEvent {
	ShapeId sensorShapeId;
	ShapeId visitorShapeId;
}

struct SensorEndTouchEvent {
	ShapeId sensorShapeId;
	ShapeId visitorShapeId;
}

struct SensorEvents {
	SensorBeginTouchEvent *beginEvents;
	SensorEndTouchEvent *endEvents;
	int beginCount;
	int endCount;
}

struct ContactBeginTouchEvent {
	ShapeId shapeIdA;
	ShapeId shapeIdB;
	ContactId contactId;
}

struct ContactEndTouchEvent {
	ShapeId shapeIdA;
	ShapeId shapeIdB;
	ContactId contactId;
}

struct ContactHitEvent {
	ShapeId shapeIdA;
	ShapeId shapeIdB;
	ContactId contactId;
	Pos point;
	Vec3 normal;
	float approachSpeed;
	ulong userMaterialIdA;
	ulong userMaterialIdB;
}

struct ContactEvents {
	ContactBeginTouchEvent *beginEvents;
	ContactEndTouchEvent *endEvents;
	ContactHitEvent *hitEvents;
	int beginCount;
	int endCount;
	int hitCount;
}

struct BodyMoveEvent {
	void* userData;
	WorldTransform transform;
	BodyId bodyId;
	bool fellAsleep;
}

struct BodyEvents {
	BodyMoveEvent *moveEvents;
	int moveCount;
}

struct JointEvent {
	JointId jointId;
	void *userData;
}

struct JointEvents {
	JointEvent *jointEvents;
	int count;
}

struct ContactData {
	ContactId contactId;
	ShapeId shapeIdA;
	ShapeId shapeIdB;
	Manifold *manifolds;
	int manifoldCount;
}

struct QueryFilter {
	ulong categoryBits;
	ulong maskBits;
	ulong id;
	ZString name;
}

extern fn QueryFilter defaultQueryFilter() @cname("b3DefaultQueryFilter");

struct RayCastInput {
	Vec3 origin;
	Vec3 translation;
	float maxFraction;
}

struct RayResult {
	ShapeId shapeId;
	Pos point;
	Vec3 normal;
	ulong userMaterialId;
	float fraction;
	int triangleIndex;
	int childIndex;
	int nodeVisits;
	int leafVisits;
	bool hit;
}

struct ShapeProxy {
	Vec3 *points;
	int count;
	float radius;
}

struct ShapeCastInput {
	ShapeProxy proxy;
	Vec3 translation;
	float maxFraction;
	bool canEncroach;
}

struct BoxCastInput {
	Aabb box;
	Vec3 translation;
	float maxFraction;
}

struct CastOutput {
	Vec3 normal;
	Vec3 point;
	float fraction;
	int iterations;
	int triangleIndex;
	int childIndex;
	int materialIndex;
	bool hit;
}

struct WorldCastOutput @if($feature(BOX3D_DOUBLE_PRECISION)) {
	Vec3 normal;
	Pos point;
	float fraction;
	int iterations;
	int triangleIndex;
	int childIndex;
	int materialIndex;
	bool hit;
}

alias WorldCastOutput @if(!$feature(BOX3D_DOUBLE_PRECISION)) = CastOutput;

struct BodyCastResult {
	ShapeId shapeId;
	Pos point;
	Vec3 normal;
	float fraction;
	int triangleIndex;
	ulong userMaterialId;
	int iterations;
	bool hit;
}

struct SimplexCache {
	float metric;
	ushort count;
	char[4] indexA;
	char[4] indexB;

}

const SimplexCache EMPTY_DISTANCE_CACHE = {}; //C3 zero-initializes by default so this is kinda pointless

struct ShapeCastPairInput {
	ShapeProxy proxyA;
	ShapeProxy proxyB;
	Transform transform;
	Vec3 translationB;
	float maxFraction;
	bool canEncroach;
}

struct DistanceInput {
	ShapeProxy proxyA;
	ShapeProxy proxyB;
	Transform transform;
	bool useRadii;
}

struct DistanceOutput {
	Vec3 pointA;
	Vec3 pointB;
	Vec3 normal;
	float distance;
	int iterations;
	int simplexCount;
}

struct SimplexVertex {
	Vec3 wA;
	Vec3 wB;
	Vec3 w;
	float a;
	int indexA;
	int indexB;
}

struct Simplex {
	SimplexVertex[4] vertices;
	int count;
}

struct Sweep {
	Vec3 localCenter;
	Vec3 c1;
	Vec3 c2;
	Quat q1;
	Quat q2;
}

struct TOIInput {
	ShapeProxy proxyA;
	ShapeProxy proxyB;
	Sweep sweepA;
	Sweep sweepB;
	float maxFraction;
}

constdef TOIState {
	UNKNOWN,
	FAILED,
	OVERLAPPED,
	HIT,
	SEPARATED
}

struct TOIOutput {
	TOIState state;
	Vec3 point;
	Vec3 normal;
	float fraction;
	float distance;
	int distanceIterations;
	int pushBackIterations;
	int rootIterations;
	bool usedFallback;
}

constdef TreeNodeFlags {
	ALLOCATED_NODE = 0x0001,
	ENLARGED_NODE = 0x0002,
	LEAF_NODE = 0x0004,
}

struct TreeNodeChildren {
	int child1;
	int child2;
}

struct TreeNode {
	Aabb aabb;
	ulong categoryBits;

	union {
		TreeNodeChildren children;
		ulong userData;
	}

	union {
		int parent;
		int next;
	}

	ushort height;
	ushort flags;
}

const DYNAMIC_TREE_VERSION = 0x93EDAF889FD30B4Aull;

struct DynamicTree {
	ulong version;
	TreeNode *nodes;
	int root;
	int nodeCount;
	int nodeCapacity;
	int proxyCount;
	int freeList;
	int *leafIndices;
	Aabb *leafBoxes;
	Vec3 *leafCenters;
	int *binIndices;
	int rebuildCapacity;
}

struct TreeStats {
	int nodeVisits;
	int leafVisits;
}

alias TreeQueryCallbackFcn = fn bool(int proxyId, ulong userData, void *context);
alias TreeQueryClosestCallbackFcn = fn float (float distanceSqrMin, int proxyId, ulong userData, void *context);
alias TreeBoxCastCallbackFcn = fn float (BoxCastInput *input, int proxyId, ulong userData, void * context);
alias TreeRayCastCallbackFcn = fn float (RayCastInput *input, int proxyId, ulong userData, void * context);


struct PlaneResult {
	Plane plane;
	Vec3 point;
}

struct CollisionPlane {
	Plane plane;
	float pushLimit;
	float push;
	bool clipVelocity;
}

struct PlaneSolverResult {
	Vec3 delta;
	int iterationCount;
}

struct BodyPlaneResult {
	ShapeId shapeId;
	PlaneResult result;
}

alias PlaneResultFcn = fn bool (ShapeId shapeId, PlaneResult *plane, int planeCount, void *context);
alias MoverFilterFcn = fn bool (ShapeId shapeId, void *context);

struct MassData {
	float mass;
	Vec3 center;
	Matrix3 inertia;
}

struct Sphere {
	Vec3 center;
	float radius;
}

struct Capsule {
	Vec3 center1;
	Vec3 center2;
	float radius;
}

struct HullVertex {
	char edge;
}

struct HullHalfEdge {
	char next;
	char twin;
	char origin;
	char face;
}

struct HullFace {
	char edge;
}

const HULL_VERSION = 0x9D4716CE3793900Eull;

struct HullData {
	ulong version;
	int byteCount;
	uint hash;
	Aabb aabb;
	float surfaceArea;
	float volume;
	float innerRadius;
	Vec3 center;
	Matrix3 centralInertia;
	int vertexCount;
	int vertexOffset;
	int pointOffset;
	int edgeCount;
	int edgeOffset;
	int faceCount;
	int faceOffset;
	int planeOffset;
	int padding;
}

struct BoxHull {
	HullData base;
	HullVertex[8] boxVertices;
	Vec3[8] boxPoints;
	HullHalfEdge[24] boxEdges;
	HullFace[6] boxFaces;
	char[2] padding;
	Plane[6] boxPlanes;
}

struct MeshDef {
	Vec3 *vertices;
	int *indices;
	char *materialIndices;
	float weldTolerance;
	int vertexCount;
	int triangleCount;
	bool weldVertices;
	bool useMedianSplit;
	bool identifyEdges;
}

const MESH_VERSION = 0xABD11AB62A6E886Dull;

constdef MeshEdgeFlags {
	CONCAVE_EDGE_1 = 0x01,
	CONCAVE_EDGE_2 = 0x02,
	CONCAVE_EDGE_3 = 0x04,

	INVERSE_CONCAVE_EDGE_1 = 0x10,
	INVERSE_CONCAVE_EDGE_2 = 0x20,
	INVERSE_CONCAVE_EDGE_3 = 0x40,

	ALL_CONCAVE_EDGES = CONCAVE_EDGE_1 | CONCAVE_EDGE_2 | CONCAVE_EDGE_3,

	FLAT_EDGE_1 = CONCAVE_EDGE_1 | INVERSE_CONCAVE_EDGE_1,
	FLAT_EDGE_2 = CONCAVE_EDGE_2 | INVERSE_CONCAVE_EDGE_2,
	FLAT_EDGE_3 = CONCAVE_EDGE_3 | INVERSE_CONCAVE_EDGE_3,

	ALL_FLAT_EDGES = FLAT_EDGE_1 | FLAT_EDGE_2 | FLAT_EDGE_3
}

struct MeshTriangle {
	int index1;
	int index2;
	int index3;
}

struct MeshNode {
	Vec3 lowerBound;

	union data {
		bitstruct asNode : uint {
			uint axis : 0..1;
			uint childOffset : 2..31;
		}

		bitstruct asLeaf : uint {
			uint type : 0..1;
			uint triangleCount : 2..31;
		}
	}

	Vec3 upperBound;
	uint triangleOffset;
}

struct MeshData {
	ulong version;
	int byteCount;
	uint hash;
	Aabb bounds;
	float surfaceArea;
	int treeHeight;
	int degenerateCount;
	int nodeOffset;
	int nodeCount;
	int vertexOffset;
	int vertexCount;
	int triangleOffset;
	int triangleCount;
	int materialOffset;
	int materialCount;
	int flagsOffset;
}

struct Mesh {
	MeshData *data;
	Vec3 scale;
}

struct HeightFieldDef {
	float *heights;
	char *materialIndices;
	Vec3 scale;
	int countX;
	int countZ;
	float globalMinimumHeight;
	float globalMaximumHeight;
	bool clockwiseWinding;
}

const HEIGHT_FIELD_HOLE = 0xFF;
const HEIGHT_FIELD_VERSION = 0x8B18CBD138A6BC84ull;

struct HeightFieldData {
	ulong version;
	int byteCount;
	uint hash;
	Aabb aabb;
	float minHeight;
	float maxHeight;
	float heightScale;
	Vec3 scale;
	int columnCount;
	int rowCount;
	int heightsOffset;
	int materialOffset;
	int flagsOffset;
	bool clockwise;
	char[3] padding;
}

struct CompoundCapsuleDef {
	Capsule capsule;
	SurfaceMaterial material;
}

struct CompoundHullDef {
	HullData *hull;
	Transform transform;
	SurfaceMaterial material;
}

struct CompoundMeshDef {
	MeshData *meshData;
	Transform transform;
	Vec3 scale;
	SurfaceMaterial *materials;
	int materialCount;
}

struct CompoundSphereDef {
	Sphere sphere;
	SurfaceMaterial material;
}

struct CompoundDef {
	CompoundCapsuleDef *capsules;
	int capsuleCount;
	CompoundHullDef *hulls;
	int hullCount;
	CompoundMeshDef *meshes;
	int meshCount;
	CompoundSphereDef *spheres;
	int sphereCount;
}

const COMPOUND_VERSION = (0x830778DB07086EB4ull ^ DYNAMIC_TREE_VERSION ^ MESH_VERSION ^ HULL_VERSION);
const MAX_COMPOUND_MESH_MATERIALS = 4;

struct CompoundData {
	ulong version;
	int byteCount;
	int nodeOffset;
	DynamicTree tree;
	int materialOffset;
	int materialCount;
	int capsuleOffset;
	int capsuleCount;
	int hullOffset;
	int hullCount;
	int sharedHullCount;
	int meshOffset;
	int meshCount;
	int sharedMeshCount;
	int sphereOffset;
	int sphereCount;
}

struct CompoundCapsule {
	Capsule capsule;
	int materialIndex;
}

struct CompoundHull {
	HullData *hull;
	Transform transform;
	int materialIndex;
}

struct CompoundMesh {
	MeshData *meshData;
	Transform transform;
	Vec3 scale;
	int[MAX_COMPOUND_MESH_MATERIALS] materialIndices;
}

struct CompoundSphere {
	Sphere sphere;
	int materialIndex;
}

struct ChildShape {
	union {
		Capsule capsule;
		HullData *hull;
		Mesh mesh;
		Sphere sphere;
	}

	Transform transform;
	int[MAX_COMPOUND_MESH_MATERIALS] materialIndices;
	ShapeType type;
}

alias CompoundQueryFcn = fn bool (CompoundData *compound, int childIndex, void *context);

struct ManifoldPoint {
	Vec3 anchorA;
	Vec3 anchorB;
	float separation;
	float baseSeparation;
	float normalImpulse;
	float totalNormalImpulse;
	float normalVelocity;
	uint featureId;
	int triangleIndex;
	bool persisted;
}

struct Manifold {
	ManifoldPoint[MAX_MANIFOLD_POINTS] points;
	Vec3 normal;
	float twistImpulse;
	Vec3 frictionImpulse;
	Vec3 rollingImpulse;
	int pointCount;

}

constdef SeparatingFeature {
	INVALID_AXIS = 0,
	BACKSIDE_AXIS,
	FACE_AXIS_A,
	FACE_AXIS_B,
	EDGE_PAIR_AXIS,
	CLOSEST_POINTS_AXIS,

	MANUAL_FACE_AXIS_A,
	MANUAL_FACE_AXIS_B,
	MANUAL_EDGE_PAIR_AXIS,
}

constdef TriangleFeature {
	NODE = 0,
	TRIANGLE_FACE,
	HULL_FACE,
	EDGE_1,
	EDGE_2,
	EDGE_3,
	VERTEX_1,
	VERTEX_2,
	VERTEX_3,
}

struct SATCache {
	float separation;
	char type;
	char indexA;
	char indexB;
	char hit;
}

struct FeaturePair {
	char owner1;
	char index1;
	char owner2;
	char index2;
}

struct LocalManifoldPoint {
	Vec3 point;
	float separation;
	FeaturePair pair;
	int triangleIndex;
}

struct LocalManifold {
	Vec3 normal;
	Vec3 triangleNormal;
	LocalManifoldPoint *points;
	int pointCount;
	int triangleIndex;
	int i1;
	int i2;
	int i3;
	float squaredDistance;
	TriangleFeature feature;
	int triangleFlags;
}

constdef HexColor {
	ALICE_BLUE = 0xF0F8FF,
	ANTIQUE_WHITE = 0xFAEBD7,
	AQUA = 0x00FFFF,
	AQUAMARINE = 0x7FFFD4,
	AZURE = 0xF0FFFF,
	BEIGE = 0xF5F5DC,
	BISQUE = 0xFFE4C4,
	BLACK = 0x000000,
	BLANCHED_ALMOND = 0xFFEBCD,
	BLUE = 0x0000FF,
	BLUE_VIOLET = 0x8A2BE2,
	BROWN = 0xA52A2A,
	BURLYWOOD = 0xDEB887,
	CADET_BLUE = 0x5F9EA0,
	CHARTREUSE = 0x7FFF00,
	CHOCOLATE = 0xD2691E,
	CORAL = 0xFF7F50,
	CORNFLOWER_BLUE = 0x6495ED,
	CORNSILK = 0xFFF8DC,
	CRIMSON = 0xDC143C,
	CYAN = 0x00FFFF,
	DARK_BLUE = 0x00008B,
	DARK_CYAN = 0x008B8B,
	DARK_GOLDEN_ROD = 0xB8860B,
	DARK_GRAY = 0xA9A9A9,
	DARK_GREEN = 0x006400,
	DARK_KHAKI = 0xBDB76B,
	DARK_MAGENTA = 0x8B008B,
	DARK_OLIVE_GREEN = 0x556B2F,
	DARK_ORANGE = 0xFF8C00,
	DARK_ORCHID = 0x9932CC,
	DARK_RED = 0x8B0000,
	DARK_SALMON = 0xE9967A,
	DARK_SEA_GREEN = 0x8FBC8F,
	DARK_SLATE_BLUE = 0x483D8B,
	DARK_SLATE_GRAY = 0x2F4F4F,
	DARK_TURQUOISE = 0x00CED1,
	DARK_VIOLET = 0x9400D3,
	DEEP_PINK = 0xFF1493,
	DEEP_SKY_BLUE = 0x00BFFF,
	DIM_GRAY = 0x696969,
	DODGER_BLUE = 0x1E90FF,
	FIRE_BRICK = 0xB22222,
	FLORAL_WHITE = 0xFFFAF0,
	FOREST_GREEN = 0x228B22,
	FUCHSIA = 0xFF00FF,
	GAINSBORO = 0xDCDCDC,
	GHOST_WHITE = 0xF8F8FF,
	GOLD = 0xFFD700,
	GOLDEN_ROD = 0xDAA520,
	GRAY = 0x808080,
	GREEN = 0x008000,
	GREEN_YELLOW = 0xADFF2F,
	HONEY_DEW = 0xF0FFF0,
	HOT_PINK = 0xFF69B4,
	INDIAN_RED = 0xCD5C5C,
	INDIGO = 0x4B0082,
	IVORY = 0xFFFFF0,
	KHAKI = 0xF0E68C,
	LAVENDER = 0xE6E6FA,
	LAVENDER_BLUSH = 0xFFF0F5,
	LAWN_GREEN = 0x7CFC00,
	LEMON_CHIFFON = 0xFFFACD,
	LIGHT_BLUE = 0xADD8E6,
	LIGHT_CORAL = 0xF08080,
	LIGHT_CYAN = 0xE0FFFF,
	LIGHT_GOLDEN_ROD_YELLOW = 0xFAFAD2,
	LIGHT_GRAY = 0xD3D3D3,
	LIGHT_GREEN = 0x90EE90,
	LIGHT_PINK = 0xFFB6C1,
	LIGHT_SALMON = 0xFFA07A,
	LIGHT_SEA_GREEN = 0x20B2AA,
	LIGHT_SKY_BLUE = 0x87CEFA,
	LIGHT_SLATE_GRAY = 0x778899,
	LIGHT_STEEL_BLUE = 0xB0C4DE,
	LIGHT_YELLOW = 0xFFFFE0,
	LIME = 0x00FF00,
	LIME_GREEN = 0x32CD32,
	LINEN = 0xFAF0E6,
	MAGENTA = 0xFF00FF,
	MAROON = 0x800000,
	MEDIUM_AQUA_MARINE = 0x66CDAA,
	MEDIUM_BLUE = 0x0000CD,
	MEDIUM_ORCHID = 0xBA55D3,
	MEDIUM_PURPLE = 0x9370DB,
	MEDIUM_SEA_GREEN = 0x3C71,
	MEDIUM_SLATE_BLUE = 0x7B68EE,
	MEDIUM_SPRING_GREEN = 0x00FA9A,
	MEDIUM_TURQUOISE = 0x48D1CC,
	MEDIUM_VIOLET_RED = 0xC71585,
	MDINIGHT_BLUE = 0x191970,
	MINT_CREAM = 0xF5FFFA,
	MISTY_ROSE = 0xFFE4E1,
	MOCCASIN = 0xFFE4B5,
	NAVAJO_WHITE = 0xFFDEAD,
	NAVY = 0x000080,
	OLD_LACE = 0xFDF5E6,
	OLIVE = 0x808000,
	OLIVE_DRAB = 0x6B8E23,
	ORANGE = 0xFFA500,
	ORANGE_RED = 0xFF4500,
	ORCHID = 0xDA70D6,
	PALE_GOLDEN_ROD = 0xEEE8AA,
	PALE_GREEN = 0x98FB98,
	PALE_TURQUOISE = 0xAFEEEE,
	PALE_VIOLET_RED = 0xDB7093,
	PAPAYA_WHIP = 0xFFEFD5,
	PEACH_PUFF = 0xFFDAB9,
	PERU = 0xCD853F,
	PINK = 0xFFC0CB,
	PLUM = 0xDDA0DD,
	POWDER_BLUE = 0xB0E0E6,
	PURPLE = 0x800080,
	REBECCA_PURPLE = 0x663399,
	RED = 0xFF0000,
	ROSY_BROWN = 0xBC8F8F,
	ROYAL_BLUE = 0x4169E1,
	SADDLE_BROWN = 0x8B4513,
	SALMON = 0xFA8072,
	SANDY_BROWN = 0xF4A460,
	SEA_GREEN = 0x2E8B57,
	SEA_SHELL = 0xFFF5EE,
	SIENNA = 0xA0522D,
	SILVER = 0xC0C0C0,
	SKY_BLUE = 0x87CEEB,
	SLATE_BLUE = 0x6A5ACD,
	SLATE_GRAY = 0x708090,
	SNOW = 0xFFFAFA,
	SPRING_GREEN = 0x00FF7F,
	STEEL_BLUE = 0x4682B4,
	TAN = 0xD2B48C,
	TEAL = 0x008080,
	THISTLE = 0xD8BFD8,
	TOMATO = 0xFF6347,
	TURQUOISE = 0x40E0D0,
	VIOLET = 0xEE82EE,
	WHEAT = 0xF5DE,
	WHITE = 0xFFFFFF,
	WHITE_SMOKE = 0xF5F5F5,
	YELLOW = 0xFFFF00,
	YELLOW_GREEN = 0x9ACD32,

	BOX2D_RED = 0xDC3132,
	BOX2D_BLUE = 0x30AEBF,
	BOX2D_GREEN = 0x8CC924,
	BOX2D_YELLOW = 0xFFEE8C
}

constdef DebugMaterial {
	DEFAULT = 0,
	MATTE,
	SOFT,
	DEAD,
	GLOSSY,
	METALLIC
}

fn uint makeDebugColor(HexColor rgb, DebugMaterial material) @inline {
	return ((uint)rgb & 0x00FFFFFFu) | ((uint)material << 24);
}

extern fn HexColor getGraphColor(int index) @cname("b3GetGraphColor");

struct DebugShape {
	ShapeId shapeId;
	ShapeType type;

	union {
		Capsule *capsule;
		CompoundData *compound;
		HeightFieldData *heightField;
		HullData *hull;
		Mesh *mesh;
		Sphere *sphere;
	}
}

alias DrawShapeFcn = fn bool (void *userShape, WorldTransform transform, HexColor color, void* context);
alias DrawSegmentFcn = fn void (Pos p1, Pos p2, HexColor color, void *context);
alias DrawTransformFcn = fn void (WorldTransform transform, void *context);
alias DrawPointFcn = fn void (Pos p, float size, HexColor color, void *context);
alias DrawSphereFcn = fn void (Pos p, float radius, HexColor color, float alpha, void *context);
alias DrawCapsuleFcn = fn void (Pos p1, Pos p2, float radius, HexColor color, float alpha, void *context);
alias DrawBoundsFcn = fn void (Aabb aabb, HexColor color, void *context);
alias DrawBoxFcn = fn void (Vec3 extents, WorldTransform transform, HexColor color, void *context);
alias DrawStringFcn = fn void (Pos p, ZString s, HexColor color, void *context);

struct DebugDraw {
	DrawShapeFcn drawShapeFcn;
	DrawSegmentFcn drawSegmentFcn;
	DrawTransformFcn drawTransformFcn;
	DrawPointFcn drawPointFcn;
	DrawSphereFcn drawSphereFcn;
	DrawCapsuleFcn drawCapsuleFcn;
	DrawBoundsFcn drawBoundsFcn;
	DrawBoxFcn drawBoxFcn;
	DrawStringFcn drawStringFcn;

	Aabb drawingBounds;
	float forceScale;
	float jointScale;
	bool drawShapes;
	bool drawJoints;
	bool drawJointExtras;
	bool drawBounds;
	bool drawMass;
	bool drawSleep;
	bool drawBodyNames;
	bool drawContacts;
	int drawAnchorA;
	bool drawGraphColors;
	bool drawContactFeatures;
	bool drawContactNormals;
	bool drawContactForces;
	bool drawFrictionForces;
	bool drawIslands;
	void* context;
}

extern fn DebugDraw defaultDebugDraw() @cname("b3DefaultDebugDraw");


//COLLISION
extern fn DynamicTree dynamicTree_Create(int proxyCapacity) @cname("b3DynamicTree_Create");
extern fn void dynamicTree_Destroy(DynamicTree *tree) @cname("b3DynamicTree_Destroy");
extern fn int dynamicTree_CreateProxy(DynamicTree *tree, Aabb aabb, ulong categoryBits, ulong userData) @cname("b3DynamicTree_CreateProxy");
extern fn void dynamicTree_DestroyProxy(DynamicTree *tree, int proxyId) @cname("b3DynamicTree_DestroyProxy");
extern fn void dynamicTree_MoveProxy(DynamicTree *tree, int proxyId, Aabb aabb) @cname("b3DynamicTree_MoveProxy");
extern fn void dynamicTree_EnlargeProxy(DynamicTree *tree, int proxyId, Aabb aabb) @cname("b3DynamicTree_EnlargeProxy");
extern fn void dynamicTree_SetCategoryBits(DynamicTree *tree, int proxyId, ulong categoryBits) @cname("b3DynamicTree_SetCategoryBits");
extern fn ulong dynamicTree_GetCategoryBits(DynamicTree *tree, int proxyId) @cname("b3DynamicTree_GetCategoryBits");
extern fn TreeStats dynamicTree_Query(DynamicTree *tree, Aabb aabb, ulong maskBits, bool requireAllBits, TreeQueryCallbackFcn callback, void *context) @cname("b3DynamicTree_Query");
extern fn TreeStats dynamicTree_QueryClosest(DynamicTree *tree, Vec3 point, ulong maskBits, bool requireAllBits, TreeQueryClosestCallbackFcn callback, void *context, float *minDistanceSqr) @cname("b3DynamicTree_QueryClosest");
extern fn TreeStats dynamicTree_RayCast(DynamicTree *tree, RayCastInput *input, ulong maskBits, bool requireAllBits, TreeRayCastCallbackFcn callback, void *context) @cname("b3DynamicTree_RayCast");
extern fn TreeStats dynamicTree_BoxCast(DynamicTree *tree, BoxCastInput *input, ulong maskBits, bool requireAllBits, TreeBoxCastCallbackFcn callback, void *context) @cname("b3DynamicTree_BoxCast");
extern fn int dynamicTree_GetHeight(DynamicTree *tree) @cname("b3DynamicTree_GetHeight");
extern fn float dynamicTree_GetAreaRatio(DynamicTree *tree) @cname("b3DynamicTree_GetAreaRatio");
extern fn Aabb dynamicTree_GetRootBounds(DynamicTree *tree) @cname("b3DynamicTree_GetRootBounds");
extern fn int dynamicTree_GetProxyCount(DynamicTree *tree) @cname("b3DynamicTree_GetProxyCount");
extern fn int dynamicTree_Rebuild(DynamicTree *tree, bool fullBuild) @cname("b3DynamicTree_Rebuild");
extern fn int dynamicTree_GetByteCount(DynamicTree *tree) @cname("b3DynamicTree_GetByteCount");
extern fn void dynamicTree_Validate(DynamicTree *tree) @cname("b3DynamicTree_Validate");
extern fn void dynamicTree_ValidateNoEnlarged(DynamicTree *tree) @cname("b3DynamicTree_ValidateNoEnlarged");
extern fn void dynamicTree_Save(DynamicTree *tree, ZString fileName) @cname("b3DynamicTree_Save");
extern fn DynamicTree dynamicTree_Load(ZString fileName, float scale) @cname("b3DynamicTree_Load");

fn ulong dynamicTree_GetUserData(DynamicTree *tree, int proxyId) @inline {
	return tree.nodes[proxyId].userData;
}

fn Aabb dynamicTree_GetAABB(DynamicTree *tree, int proxyId) @inline {
	return tree.nodes[proxyId].aabb;
}

fn HullVertex* getHullVertices(HullData *hull) @inline {
	if(hull.vertexOffset == 0) return null;
	return (HullVertex*)((iptr)hull + hull.vertexOffset);
}

fn Vec3* getHullPoints(HullData *hull) @inline {
	if(hull.pointOffset == 0) return null;
	return (Vec3*)((iptr)hull + hull.pointOffset);
}

fn HullHalfEdge* getHullEdges(HullData *hull) @inline {
	if(hull.edgeOffset == 0) return null;
	return (HullHalfEdge*)((iptr)hull + hull.edgeOffset);
}

fn HullFace* getHullFaces(HullData *hull) @inline {
	if(hull.faceOffset == 0) return null;
	return (HullFace*)((iptr)hull + hull.faceOffset);
}

fn Plane* getHullPlanes(HullData *hull) @inline {
	if(hull.planeOffset == 0) return null;
	return (Plane*)((iptr)hull + hull.planeOffset);
}

extern fn HullData* createCylinder(float height, float radius, float yOffset, int sides) @cname("b3CreateCylinder");
extern fn HullData* createCone(float height, float radius1, float radius2, int slices) @cname("b3CreateCone");
extern fn HullData* createRock(float radius) @cname("b3CreateRock");
extern fn HullData* createHull(Vec3 *points, int pointCount, int maxVertexCount) @cname("b3CreateHull");
extern fn HullData* cloneHull(HullData *hull) @cname("b3CloneHull");
extern fn HullData* cloneAndTransformHull(HullData *original, Transform transform, Vec3 scale) @cname("b3CloneAndTransformHull");
extern fn void destroyHull(HullData *hull) @cname("b3DestroyHull");
extern fn BoxHull makeCubeHull(float halfWidth) @cname("b3MakeCubeHull");
extern fn BoxHull makeBoxHull(float hx, float hy, float hz) @cname("b3MakeBoxHull");
extern fn BoxHull makeOffsetBoxHull(float hx, float hy, float hz, Vec3 offset) @cname("b3MakeOffsetBoxHull");
extern fn BoxHull makeTransformedBoxHull(float hx, float hy, float hz, Transform transform) @cname("b3MakeTransformedBoxHull");
extern fn BoxHull makeScaledBoxHull(Vec3 halfWidths, Transform transform, Vec3 postScale) @cname("b3MakeScaledBoxHull");
extern fn void scaleBox(Vec3 *halfWidths, Transform *transform, Vec3 postScale, float minHalfWidth) @cname("b3ScaleBox");

fn MeshNode* getMeshNodes(MeshData *mesh) @inline {
	if(mesh.nodeOffset == 0) return null;
	return (MeshNode*)((iptr)mesh + mesh.nodeOffset);
}

fn Vec3* getMeshVertices(MeshData *mesh) @inline {
	if(mesh.vertexOffset == 0) return null;
	return (Vec3*)((iptr)mesh + mesh.vertexOffset);
}

fn MeshTriangle* getMeshTriangles(MeshData *mesh) @inline {
	if(mesh.triangleOffset == 0) return null;
	return (MeshTriangle*)((iptr)mesh + mesh.triangleOffset);
}

fn char* getMeshMaterialIndices(MeshData *mesh) @inline {
	if (mesh.materialOffset == 0) return null;
	return (char*)((iptr)mesh + mesh.materialOffset);
}

fn char* getMeshFlags(MeshData *mesh) @inline {
	if(mesh.flagsOffset == 0) return null;
	return (char*)((iptr)mesh + mesh.flagsOffset);
}

extern fn MeshData* createGridMesh(int xCount, int zCount, float cellWidth, int materialCount, bool identifyEdges) @cname("b3CreateGridMesh");
extern fn MeshData* createWaveMesh(int xCount, int zCount, float cellWidth, float amplitude, float rowFrequency, float columnFrequency) @cname("b3CreateWaveMesh");
extern fn MeshData* createTorusMesh(int radialResolution, int tubularResolution, float radius, float thickness) @cname("b3CreateTorusMesh");
extern fn MeshData* createBoxMesh(Vec3 center, Vec3 extent, bool identifyEdges) @cname("b3CreateBoxMesh");
extern fn MeshData* createHollowBoxMesh(Vec3 center, Vec3 extent) @cname("b3CreateHollowBoxMesh");
extern fn MeshData* createPlatformMesh(Vec3 center, float height, float topWidth, float bottomWidth) @cname("b3CreatePlatformMesh");
extern fn MeshData* createMesh(MeshDef *def, int *degenerateTriangleIndices, int degenerateCapacity) @cname("b3CreateMesh");
extern fn void destroyMesh(MeshData *mesh) @cname("b3DestroyMesh");
extern fn int getHeight(MeshData *mesh) @cname("b3GetHeight");

fn ushort* getHeightFieldCompressedHeights(HeightFieldData *hf) @inline {
	if(hf.heightsOffset == 0) return null;
	return (ushort*)((iptr)hf + hf.heightsOffset);
}

fn char* getHeightFieldMaterialIndices(HeightFieldData *hf) @inline {
	if(hf.materialOffset == 0) return null;
	return (char*)((iptr)hf + hf.materialOffset);
}

fn char* getHeightFieldFlags(HeightFieldData *hf) @inline {
	if(hf.flagsOffset == 0) return null;
	return (char*)((iptr)hf + hf.flagsOffset);
}

extern fn HeightFieldData *createHeightField(HeightFieldDef *data) @cname("b3CreateHeightField");
extern fn HeightFieldData *createGrid(int rowCount, int columnCount, Vec3 scale, bool makeHoles) @cname("b3CreateGrid");
extern fn HeightFieldData *createWave(int rowCount, int columnCount, Vec3 scale, float rowFrequency, float columnFrequency, bool makeHoles) @cname("b3CreateWave");
extern fn void destroyHeightField(HeightFieldData *heightField) @cname("b3DestroyHeightField");
extern fn void dumpHeightData(HeightFieldDef *data, ZString fileName) @cname("b3DumpHeightData");
extern fn HeightFieldData *loadHeightField(ZString fileName) @cname("b3LoadHeightField");
extern fn ChildShape getCompoundChild(CompoundData *compound, int childIndex) @cname("b3GetCompoundChild");
extern fn void queryCompound(CompoundData *compound, Aabb aabb, CompoundQueryFcn fcn, void *context) @cname("b3QueryCompound");
extern fn CompoundCapsule getCompoundCapsule(CompoundData *compound, int index) @cname("b3GetCompoundCapsule");
extern fn CompoundHull getCompoundHull(CompoundData *compound, int index) @cname("b3GetCompoundHull");
extern fn CompoundMesh getCompoundMesh(CompoundData *compound, int index) @cname("b3GetCompoundMesh");
extern fn CompoundSphere getCompoundSphere(CompoundData *compound, int index) @cname("b3GetCompoundSphere");
extern fn SurfaceMaterial *getCompoundMaterials(CompoundData *compound) @cname("b3GetCompoundMaterials");
extern fn CompoundData *createCompound(CompoundDef *def) @cname("b3CreateCompound");
extern fn void destroyCompound(CompoundData *compound) @cname("b3DestroyCompound");
extern fn char *convertCompoundToBytes(CompoundData *compound) @cname("b3ConvertCompoundToBytes");
extern fn CompoundData *convertBytesToCompound(char *bytes, int byteCount) @cname("b3ConvertBytesToCompound");
extern fn MassData computeSphereMass(Sphere *shape, float density) @cname("b3ComputeSphereMass");
extern fn MassData computeCapsuleMass(Capsule *shape, float density) @cname("b3ComputeCapsuleMass");
extern fn MassData computeHullMass(HullData *shape, float density) @cname("b3ComputeHullMass");
extern fn Aabb computeSphereAABB(Sphere *shape, Transform transform) @cname("b3ComputeSphereAABB");
extern fn Aabb computeCapsuleAABB(Capsule *shape, Transform transform) @cname("b3ComputeCapsuleAABB");
extern fn Aabb computeHullAABB(HullData *shape, Transform transform) @cname("b3ComputeHullAABB");
extern fn Aabb computeMeshAABB(MeshData *shape, Transform transform, Vec3 scale) @cname("b3ComputeMeshAABB");
extern fn Aabb computeHeightFieldAABB(HeightFieldData *shape, Transform transform) @cname("b3ComputeHeightFieldAABB");
extern fn Aabb computeCompoundAABB(CompoundData *shape, Transform transform) @cname("b3ComputeCompoundAABB");
extern fn bool isValidRay(RayCastInput *input) @cname("b3IsValidRay");
extern fn bool overlapCapsule(Capsule *shape, Transform shapeTransform, ShapeProxy *proxy) @cname("b3OverlapCapsule");
extern fn bool overlapCompound(CompoundData *shape, Transform shapeTransform, ShapeProxy *proxy) @cname("b3OverlapCompound");
extern fn bool overlapHeightField(HeightFieldData *shape, Transform shapeTransform, ShapeProxy *proxy) @cname("b3OverlapHeightField");
extern fn bool overlapHull(HullData *shape, Transform shapeTransform, ShapeProxy *proxy) @cname("b3OverlapHull");
extern fn bool overlapMesh(Mesh *shape, Transform shapeTransform, ShapeProxy *proxy) @cname("b3OverlapMesh");
extern fn bool overlapSphere(Sphere *shape, Transform shapeTransform, ShapeProxy *proxy) @cname("b3OverlapSphere");
extern fn CastOutput rayCastSphere(Sphere *shape, RayCastInput *input) @cname("b3RayCastSphere");
extern fn CastOutput rayCastHollowSphere(Sphere *shape, RayCastInput *input) @cname("b3RayCastHollowSphere");
extern fn CastOutput rayCastCapsule(Capsule *shape, RayCastInput *input) @cname("b3RayCastCapsule");
extern fn CastOutput rayCastCompound(CompoundData *shape, RayCastInput *input) @cname("b3RayCastCompound");
extern fn CastOutput rayCastHull(HullData *shape, RayCastInput *input) @cname("b3RayCastHull");
extern fn CastOutput rayCastMesh(Mesh *shape, RayCastInput *input) @cname("b3RayCastMesh");
extern fn CastOutput rayCastHeightField(HeightFieldData *shape, RayCastInput *input) @cname("b3RayCastHeightField");
extern fn CastOutput shapeCastSphere(Sphere *shape, ShapeCastInput *input) @cname("b3ShapeCastSphere");
extern fn CastOutput shapeCastCapsule(Capsule *shape, ShapeCastInput *input) @cname("b3ShapeCastCapsule");
extern fn CastOutput shapeCastCompound(CompoundData *shape, ShapeCastInput *input) @cname("b3ShapeCastCompound");
extern fn CastOutput shapeCastHull(HullData *shape, ShapeCastInput *input) @cname("b3ShapeCastHull");
extern fn CastOutput shapeCastMesh(Mesh *shape, ShapeCastInput *input) @cname("b3ShapeCastMesh");
extern fn CastOutput shapeCastHeightField(HeightFieldData *shape, ShapeCastInput *input) @cname("b3ShapeCastHeightField");

alias MeshQueryFcn = fn bool (Vec3 a, Vec3 b, Vec3 c, int triangleIndex, void *context);

extern fn void queryMesh(Mesh *mesh, Aabb bounds, MeshQueryFcn fcn, void *context) @cname("b3QueryMesh");
extern fn void queryHeightField(HeightFieldData *heightField, Aabb bounds, MeshQueryFcn fcn, void *context) @cname("b3QueryHeightField");
extern fn DistanceOutput shapeDistance(DistanceInput *input, SimplexCache *cache, Simplex *simplexes, int simplexCapacity) @cname("b3ShapeDistance");
extern fn CastOutput shapeCast(ShapeCastPairInput *input) @cname("b3ShapeCast");
extern fn Transform getSweepTransform(Sweep *sweep, float time) @cname("b3GetSweepTransform");
extern fn TOIOutput timeOfImpact(TOIInput *input) @cname("b3TimeOfImpact");
extern fn void collideSpheres(LocalManifold *manifold, int capacity, Sphere *sphereA, Sphere *sphereB, Transform transformBtoA) @cname("b3CollideSpheres");
extern fn void collideCapsuleAndSphere(LocalManifold *manifold, int capacity, Capsule *capsuleA, Sphere *sphereB, Transform transformBtoA) @cname("b3CollideCapsuleAndSphere");
extern fn void collideHullAndSphere(LocalManifold *manifold, int capacity, HullData *hullA, Sphere *sphereB, Transform transformBtoA, SimplexCache *cache) @cname("b3CollideHullAndSphere");
extern fn void collideCapsules(LocalManifold *manifold, int capacity, Capsule *capsuleA, Capsule *capsuleB, Transform transformBtoA) @cname("b3CollideCapsules");
extern fn void collideHullAndCapsule(LocalManifold *manifold, int capacity, HullData *hullA, Capsule *capsuleB, Transform transformBtoA, SimplexCache *cache) @cname("b3CollideHullAndCapsule");
extern fn void collideHulls(LocalManifold *manifold, int capacity, HullData *hullA, HullData *hullB, Transform transformBtoA, SATCache *cache) @cname("b3CollideHulls");
extern fn void collideCapsuleAndTriangle(LocalManifold *manifold, int capacity, Capsule *capsuleA, Vec3 *triangleB, SimplexCache *cache) @cname("b3CollideCapsuleAndTriangle");
extern fn void collideHullAndTriangle(LocalManifold *manifold, int capacity, HullData *hullA, Vec3 v1, Vec3 v2, Vec3 v3, int triangleFlags, SATCache *cache) @cname("b3CollideHullAndTriangle");
extern fn void collideSphereAndTriangle(LocalManifold *manifold, int capacity, Sphere *sphereA, Vec3 *triangleB) @cname("b3CollideSphereAndTriangle");
extern fn PlaneSolverResult solvePlanes(Vec3 targetDelta, CollisionPlane *planes, int count) @cname("b3SolvePlanes");
extern fn Vec3 clipVector(Vec3 vector, CollisionPlane *planes, int count) @cname("b3ClipVector");


//BOX3D
alias Recording = void;

extern fn WorldId createWorld(WorldDef *def) @cname("b3CreateWorld") @if(!$feature(BOX3D_DOUBLE_PRECISION));
extern fn WorldId createWorld(WorldDef *def) @cname("b3CreateWorldDoublePrecision") @if($feature(BOX3D_DOUBLE_PRECISION));
extern fn void destroyWorld(WorldId worldId) @cname("b3DestroyWorld");
extern fn int getWorldCount() @cname("b3GetWorldCount");
extern fn int getMaxWorldCount() @cname("b3GetMaxWorldCount");
extern fn bool world_IsValid(WorldId id) @cname("b3World_IsValid");
extern fn void world_Step(WorldId worldId, float timeStep, int subStepCount) @cname("b3World_Step");
extern fn void world_Draw(WorldId worldId, DebugDraw *draw, ulong maskBits) @cname("b3World_Draw");
extern fn Aabb world_GetBounds(WorldId worldId) @cname("b3World_GetBounds");
extern fn BodyEvents world_GetBodyEvents(WorldId worldId) @cname("b3World_GetBodyEvents");
extern fn SensorEvents world_GetSensorEvents(WorldId worldId) @cname("b3World_GetSensorEvents");
extern fn ContactEvents world_GetContactEvents(WorldId worldId) @cname("b3World_GetContactEvents");
extern fn JointEvents world_GetJointEvents(WorldId worldId) @cname("b3World_GetJointEvents");
extern fn TreeStats world_OverlapAABB(WorldId worldId, Aabb aabb, QueryFilter filter, OverlapResultFcn fcn, void *context) @cname("b3World_OverlapAABB");
extern fn TreeStats world_OverlapShape(WorldId worldId, Pos origin, ShapeProxy *proxy, QueryFilter filter, OverlapResultFcn fcn, void *context) @cname("b3World_OverlapShape");
extern fn TreeStats world_CastRay(WorldId worldId, Pos origin, Vec3 translation, QueryFilter filter, CastResultFcn fcn, void *context) @cname("b3World_CastRay");
extern fn RayResult world_CastRayClosest(WorldId worldId, Pos origin, Vec3 translation, QueryFilter filter) @cname("b3World_CastRayClosest");
extern fn TreeStats world_CastShape(WorldId worldId, Pos origin, ShapeProxy *proxy, Vec3 translation, QueryFilter filter, CastResultFcn fcn, void *context) @cname("b3World_CastShape");
extern fn float world_CastMover(WorldId worldId, Pos origin, Capsule *mover, Vec3 translation, QueryFilter filter, MoverFilterFcn fcn, void *context) @cname("b3World_CastMover");
extern fn void world_CollideMover(WorldId worldId, Pos origin, Capsule *mover, QueryFilter filter, PlaneResultFcn fcn, void *context) @cname("b3World_CollideMover");
extern fn void world_EnableSleeping(WorldId worldId, bool flag) @cname("b3World_EnableSleeping");
extern fn bool world_IsSleepingEnabled(WorldId worldId) @cname("b3World_IsSleepingEnabled");
extern fn void world_EnableContinuous(WorldId worldId, bool flag) @cname("b3World_EnableContinuous");
extern fn bool world_IsContinuousEnabled(WorldId worldId) @cname("b3World_IsContinuousEnabled");
extern fn void world_SetRestitutionThreshold(WorldId worldId, float value) @cname("b3World_SetRestitutionThreshold");
extern fn float world_GetRestitutionThreshold(WorldId worldId) @cname("b3World_GetRestitutionThreshold");
extern fn void world_SetHitEventThreshold(WorldId worldId, float value) @cname("b3World_SetHitEventThreshold");
extern fn float world_GetHitEventThreshold(WorldId worldId) @cname("b3World_GetHitEventThreshold");
extern fn void world_SetCustomFilterCallback(WorldId worldId, CustomFilterFcn fcn, void *context) @cname("b3World_SetCustomFilterCallback");
extern fn void world_SetPreSolveCallback(WorldId worldId, PreSolveFcn fcn, void *context) @cname("b3World_SetPreSolveCallback");
extern fn void world_SetGravity(WorldId worldId, Vec3 gravity) @cname("b3World_SetGravity");
extern fn Vec3 world_GetGravity(WorldId worldId) @cname("b3World_GetGravity");
extern fn void world_Explode(WorldId worldId, ExplosionDef *explosionDef) @cname("b3World_Explode");
extern fn void world_SetContactTuning(WorldId worldId, float hertz, float dampingRatio, float contactSpeed) @cname("b3World_SetContactTuning");
extern fn void world_SetContactRecycleDistance(WorldId worldId, float recycleDistance) @cname("b3World_SetContactRecycleDistance");
extern fn float world_GetContactRecycleDistance(WorldId worldId) @cname("b3World_GetContactRecycleDistance");
extern fn void world_SetMaximumLinearSpeed(WorldId worldId, float maximumLinearSpeed) @cname("b3World_SetMaximumLinearSpeed");
extern fn float world_GetMaximumLinearSpeed(WorldId worldId) @cname("b3World_GetMaximumLinearSpeed");
extern fn void world_EnableWarmStarting(WorldId worldId, bool flag) @cname("b3World_EnableWarmStarting");
extern fn bool world_IsWarmStartingEnabled(WorldId worldId) @cname("b3World_IsWarmStartingEnabled");
extern fn int world_GetAwakeBodyCount(WorldId worldId) @cname("b3World_GetAwakeBodyCount");
extern fn Profile world_GetProfile(WorldId worldId) @cname("b3World_GetProfile");
extern fn Counters world_GetCounters(WorldId worldId) @cname("b3World_GetCounters");
extern fn Capacity world_GetMaxCapacity(WorldId worldId) @cname("b3World_GetMaxCapacity");
extern fn void world_SetUserData(WorldId worldId, void *userData) @cname("b3World_SetUserData");
extern fn void* world_GetUserData(WorldId worldId) @cname("b3World_GetUserData");
extern fn void world_SetFrictionCallback(WorldId worldId, FrictionCallback *callback) @cname("b3World_SetFrictionCallback");
extern fn void world_SetRestitutionCallback(WorldId worldId, RestitutionCallback *callback) @cname("b3World_SetRestitutionCallback");
extern fn void world_SetWorkerCount(WorldId worldId, int count) @cname("b3World_SetWorkerCount");
extern fn int world_GetWorkerCount(WorldId worldId) @cname("b3World_GetWorkerCount");
extern fn void world_DumpMemoryStats(WorldId worldId) @cname("b3World_DumpMemoryStats");
extern fn void world_DumpShapeBounds(WorldId worldId, BodyType type) @cname("b3World_DumpShapeBounds");
extern fn void world_RebuildStaticTree(WorldId worldId) @cname("b3World_RebuildStaticTree");
extern fn void world_EnableSpeculative(WorldId worldId, bool flag) @cname("b3World_EnableSpeculative");
extern fn Recording* createRecording(int byteCapacity) @cname("b3CreateRecording");
extern fn void destroyRecording(Recording *recording) @cname("b3DestroyRecording");
extern fn char* recording_GetData(Recording *recording) @cname("b3Recording_GetData");
extern fn int recording_GetSize(Recording *recording) @cname("b3Recording_GetSize");
extern fn void world_StartRecording(WorldId worldId, Recording *recording) @cname("b3World_StartRecording");
extern fn void world_StopRecording(WorldId worldId) @cname("b3World_StopRecording");
extern fn bool saveRecordingToFile(Recording *recording, ZString path) @cname("b3SaveRecordingToFile");
extern fn Recording* loadRecordingFromFile(ZString path) @cname("b3LoadRecordingFromFile");
extern fn bool validateReplay(void *data, int size, int workerCount) @cname("b3ValidateReplay");

alias RecPlayer = void;

struct RecPlayerInfo {
	int frameCount;
	int workerCount;
	float timeStep;
	int subStepCount;
	float lengthScale;
	Aabb bounds;
}

extern fn RecPlayer* recPlayer_Create(void *data, int size, int workerCount) @cname("b3RecPlayer_Create");
extern fn void recPlayer_Destroy(RecPlayer *player) @cname("b3RecPlayer_Destroy");
extern fn bool recPlayer_StepFrame(RecPlayer *player) @cname("b3RecPlayer_StepFrame");
extern fn void recPlayer_SubStepFrame(RecPlayer *player) @cname("b3RecPlayer_SubStepFrame");
extern fn void recPlayer_Restart(RecPlayer *player) @cname("b3RecPlayer_Restart");
extern fn void recPlayer_SeekFrame(RecPlayer *player, int targetFrame) @cname("b3RecPlayer_SeekFrame");
extern fn WorldId recPlayer_GetWorldId(RecPlayer *player) @cname("b3RecPlayer_GetWorldId");
extern fn int recPlayer_GetFrame(RecPlayer *player) @cname("b3RecPlayer_GetFrame");
extern fn int recPlayer_GetFrameCount(RecPlayer *player) @cname("b3RecPlayer_GetFrameCount");
extern fn bool recPlayer_IsAtEnd(RecPlayer *player) @cname("b3RecPlayer_IsAtEnd");
extern fn bool recPlayer_IsAtPreStep(RecPlayer *player) @cname("b3RecPlayer_IsAtPreStep");
extern fn bool recPlayer_HasDiverged(RecPlayer *player) @cname("b3RecPlayer_HasDiverged");
extern fn RecPlayerInfo recPlayer_GetInfo(RecPlayer *player) @cname("b3RecPlayer_GetInfo");
extern fn int recPlayer_GetDivergeFrame(RecPlayer *player) @cname("b3RecPlayer_GetDivergeFrame");
extern fn void recPlayer_SetWorkerCount(RecPlayer *player, int count) @cname("b3RecPlayer_SetWorkerCount");
extern fn void recPlayer_SetKeyframePolicy(RecPlayer *player, sz budgetBytes, int minIntervalFrames) @cname("b3RecPlayer_SetKeyframePolicy");
extern fn sz recPlayer_GetKeyframeBudget(RecPlayer *player) @cname("b3RecPlayer_GetKeyframeBudget");
extern fn int recPlayer_GetKeyframeMinInterval(RecPlayer *player) @cname("b3RecPlayer_GetKeyframeMinInterval");
extern fn int recPlayer_GetKeyframeInterval(RecPlayer *player) @cname("b3RecPlayer_GetKeyframeInterval");
extern fn sz recPlayer_GetKeyframeBytes(RecPlayer *player) @cname("b3RecPlayer_GetKeyframeBytes");
extern fn int recPlayer_GetBodyCount(RecPlayer *player) @cname("b3RecPlayer_GetBodyCount");
extern fn BodyId recPlayer_GetBodyId(RecPlayer *player, int index) @cname("b3RecPlayer_GetBodyId");
extern fn void recPlayer_SetDebugShapeCallbacks(RecPlayer *player, CreateDebugShapeCallback *createDebugShape, DestroyDebugShapeCallback *destroyDebugShape, void *context) @cname("b3RecPlayer_SetDebugShapeCallbacks");
extern fn void recPlayer_DrawFrameQueries(RecPlayer *player, DebugDraw *draw, int queryIndex, int selectedIndex) @cname("b3RecPlayer_DrawFrameQueries");

constdef RecQueryType {
	OVERLAP_AABB,
	OVERLAP_SHAPE,
	CAST_RAY,
	CAST_SHAPE,
	CAST_RAY_CLOSEST,
	CAST_MOVER,
	COLLIDE_MOVER,
}

struct RecQueryInfo {
	RecQueryType type;
	QueryFilter filter;
	Aabb aabb;
	Pos origin;
	Vec3 translation;
	int hitCount;
	ulong key;
	ulong id;
	ZString name;
}

struct RecQueryHit {
	ShapeId shape;
	Pos point;
	Vec3 normal;
	float fraction;
}

extern fn int recPlayer_GetFrameQueryCount(RecPlayer *player) @cname("b3RecPlayer_GetFrameQueryCount");
extern fn RecQueryInfo recPlayer_GetFrameQuery(RecPlayer *player, int index) @cname("b3RecPlayer_GetFrameQuery");
extern fn RecQueryHit recPlayer_GetFrameQueryHit(RecPlayer *player, int queryIndex, int hitIndex) @cname("b3RecPlayer_GetFrameQueryHit");
extern fn BodyId createBody(WorldId worldId, BodyDef *def) @cname("b3CreateBody");
extern fn void destroyBody(BodyId bodyId) @cname("b3DestroyBody");
extern fn bool body_IsValid(BodyId id) @cname("b3Body_IsValid");
extern fn BodyType body_GetType(BodyId bodyId) @cname("b3Body_GetType");
extern fn void body_SetType(BodyId bodyId, BodyType type) @cname("b3Body_SetType");
extern fn void body_SetName(BodyId bodyId, ZString name) @cname("b3Body_SetName");
extern fn ZString body_GetName(BodyId bodyId) @cname("b3Body_GetName");
extern fn void body_SetUserData(BodyId bodyId, void *userData) @cname("b3Body_SetUserData");
extern fn void* body_GetUserData(BodyId bodyId) @cname("b3Body_GetUserData");
extern fn Pos body_GetPosition(BodyId bodyId) @cname("b3Body_GetPosition");
extern fn Quat body_GetRotation(BodyId bodyId) @cname("b3Body_GetRotation");
extern fn WorldTransform body_GetTransform(BodyId bodyId) @cname("b3Body_GetTransform");
extern fn void body_SetTransform(BodyId bodyId, Pos position, Quat rotation) @cname("b3Body_SetTransform");
extern fn Vec3 body_GetLocalPoint(BodyId bodyId, Pos worldPoint) @cname("b3Body_GetLocalPoint");
extern fn Pos body_GetWorldPoint(BodyId bodyId, Vec3 localPoint) @cname("b3Body_GetWorldPoint");
extern fn Vec3 body_GetLocalVector(BodyId bodyId, Vec3 worldVector) @cname("b3Body_GetLocalVector");
extern fn Vec3 body_GetWorldVector(BodyId bodyId, Vec3 localVector) @cname("b3Body_GetWorldVector");
extern fn Vec3 body_GetLinearVelocity(BodyId bodyId) @cname("b3Body_GetLinearVelocity");
extern fn Vec3 body_GetAngularVelocity(BodyId bodyId) @cname("b3Body_GetAngularVelocity");
extern fn void body_SetLinearVelocity(BodyId bodyId, Vec3 linearVelocity) @cname("b3Body_SetLinearVelocity");
extern fn void body_SetAngularVelocity(BodyId bodyId, Vec3 angularVelocity) @cname("b3Body_SetAngularVelocity");
extern fn void body_SetTargetTransform(BodyId bodyId, WorldTransform target, float timeStep, bool wake) @cname("b3Body_SetTargetTransform");
extern fn Vec3 body_GetLocalPointVelocity(BodyId bodyId, Vec3 localPoint) @cname("b3Body_GetLocalPointVelocity");
extern fn Vec3 body_GetWorldPointVelocity(BodyId bodyId, Pos worldPoint) @cname("b3Body_GetWorldPointVelocity");
extern fn void body_ApplyForce(BodyId bodyId, Vec3 force, Pos point, bool wake) @cname("b3Body_ApplyForce");
extern fn void body_ApplyForceToCenter(BodyId bodyId, Vec3 force, bool wake) @cname("b3Body_ApplyForceToCenter");
extern fn void body_ApplyTorque(BodyId bodyId, Vec3 torque, bool wake) @cname("b3Body_ApplyTorque");
extern fn void body_ApplyLinearImpulse(BodyId bodyId, Vec3 impulse, Pos point, bool wake) @cname("b3Body_ApplyLinearImpulse");
extern fn void body_ApplyLinearImpulseToCenter(BodyId bodyId, Vec3 impulse, bool wake) @cname("b3Body_ApplyLinearImpulseToCenter");
extern fn void body_ApplyAngularImpulse(BodyId bodyId, Vec3 impulse, bool wake) @cname("b3Body_ApplyAngularImpulse");
extern fn float body_GetMass(BodyId bodyId) @cname("b3Body_GetMass");
extern fn Matrix3 body_GetLocalRotationalInertia(BodyId bodyId) @cname("b3Body_GetLocalRotationalInertia");
extern fn float body_GetInverseMass(BodyId bodyId) @cname("b3Body_GetInverseMass");
extern fn Matrix3 body_GetWorldInverseRotationalInertia(BodyId bodyId) @cname("b3Body_GetWorldInverseRotationalInertia");
extern fn Vec3 body_GetLocalCenter(BodyId bodyId) @cname("b3Body_GetLocalCenter");
extern fn Pos body_GetWorldCenter(BodyId bodyId) @cname("b3Body_GetWorldCenter");
extern fn void body_SetMassData(BodyId bodyId, MassData massData) @cname("b3Body_SetMassData");
extern fn MassData body_GetMassData(BodyId bodyId) @cname("b3Body_GetMassData");
extern fn void body_ApplyMassFromShapes(BodyId bodyId) @cname("b3Body_ApplyMassFromShapes");
extern fn void body_SetLinearDamping(BodyId bodyId, float linearDamping) @cname("b3Body_SetLinearDamping");
extern fn float body_GetLinearDamping(BodyId bodyId) @cname("b3Body_GetLinearDamping");
extern fn void body_SetAngularDamping(BodyId bodyId, float angularDamping) @cname("b3Body_SetAngularDamping");
extern fn float body_GetAngularDamping(BodyId bodyId) @cname("b3Body_GetAngularDamping");
extern fn void body_SetGravityScale(BodyId bodyId, float gravityScale) @cname("b3Body_SetGravityScale");
extern fn float body_GetGravityScale(BodyId bodyId) @cname("b3Body_GetGravityScale");
extern fn bool body_IsAwake(BodyId bodyId) @cname("b3Body_IsAwake");
extern fn void body_SetAwake(BodyId bodyId, bool awake) @cname("b3Body_SetAwake");
extern fn void body_EnableSleep(BodyId bodyId, bool enableSleep) @cname("b3Body_EnableSleep");
extern fn bool body_IsSleepEnabled(BodyId bodyId) @cname("b3Body_IsSleepEnabled");
extern fn void body_SetSleepThreshold(BodyId bodyId, float sleepThreshold) @cname("b3Body_SetSleepThreshold");
extern fn float body_GetSleepThreshold(BodyId bodyId) @cname("b3Body_GetSleepThreshold");
extern fn bool body_IsEnabled(BodyId bodyId) @cname("b3Body_IsEnabled");
extern fn void body_Disable(BodyId bodyId) @cname("b3Body_Disable");
extern fn void body_Enable(BodyId bodyId) @cname("b3Body_Enable");
extern fn void body_SetMotionLocks(BodyId bodyId, MotionLocks locks) @cname("b3Body_SetMotionLocks");
extern fn MotionLocks body_GetMotionLocks(BodyId bodyId) @cname("b3Body_GetMotionLocks");
extern fn void body_SetBullet(BodyId bodyId, bool flag) @cname("b3Body_SetBullet");
extern fn bool body_IsBullet(BodyId bodyId) @cname("b3Body_IsBullet");
extern fn void body_EnableContactRecycling(BodyId bodyId, bool flag) @cname("b3Body_EnableContactRecycling");
extern fn bool body_IsContactRecyclingEnabled(BodyId bodyId) @cname("b3Body_IsContactRecyclingEnabled");
extern fn void body_EnableHitEvents(BodyId bodyId, bool flag) @cname("b3Body_EnableHitEvents");
extern fn WorldId body_GetWorld(BodyId bodyId) @cname("b3Body_GetWorld");
extern fn int body_GetShapeCount(BodyId bodyId) @cname("b3Body_GetShapeCount");
extern fn int body_GetShapes(BodyId bodyId, ShapeId *shapeArray, int capacity) @cname("b3Body_GetShapes");
extern fn int body_GetJointCount(BodyId bodyId) @cname("b3Body_GetJointCount");
extern fn int body_GetJoints(BodyId bodyId, JointId *jointArray, int capacity) @cname("b3Body_GetJoints");
extern fn int body_GetContactCapacity(BodyId bodyId) @cname("b3Body_GetContactCapacity");
extern fn int body_GetContactData(BodyId bodyId, ContactData *contactData, int capacity) @cname("b3Body_GetContactData");
extern fn Aabb body_ComputeAABB(BodyId bodyId) @cname("b3Body_ComputeAABB");
extern fn float body_GetClosestPoint(BodyId bodyId, Vec3 *result, Vec3 target) @cname("b3Body_GetClosestPoint");
extern fn BodyCastResult body_CastRay(BodyId bodyId, Pos origin, Vec3 translation, QueryFilter filter, float maxFraction, WorldTransform bodyTransform) @cname("b3Body_CastRay");
extern fn BodyCastResult body_CastShape(BodyId bodyId, Pos origin, ShapeProxy *proxy, Vec3 translation, QueryFilter filter, float maxFraction, bool canEncroach, WorldTransform bodyTransform) @cname("b3Body_CastShape");
extern fn bool body_OverlapShape(BodyId bodyId, Pos origin, ShapeProxy *proxy, QueryFilter filter, WorldTransform bodyTransform) @cname("b3Body_OverlapShape");
extern fn int body_CollideMover(BodyId bodyId, BodyPlaneResult *bodyPlanes, int planeCapacity, Pos origin, Capsule *mover, QueryFilter filter, WorldTransform bodyTransform) @cname("b3Body_CollideMover");
extern fn ShapeId createSphereShape(BodyId bodyId, ShapeDef *def, Sphere *sphere) @cname("b3CreateSphereShape");
extern fn ShapeId createCapsuleShape(BodyId bodyId, ShapeDef *def, Capsule *capsule) @cname("b3CreateCapsuleShape");
extern fn ShapeId createHullShape(BodyId bodyId, ShapeDef *def, HullData *hull) @cname("b3CreateHullShape");
extern fn ShapeId createTransformedHullShape(BodyId bodyId, ShapeDef *def, HullData *hull, Transform transform, Vec3 scale) @cname("b3CreateTransformedHullShape");
extern fn ShapeId createMeshShape(BodyId bodyId, ShapeDef *def, MeshData *mesh, Vec3 scale) @cname("b3CreateMeshShape");
extern fn ShapeId createHeightFieldShape(BodyId bodyId, ShapeDef *def, HeightFieldData *heightField) @cname("b3CreateHeightFieldShape");
extern fn ShapeId createCompoundShape(BodyId bodyId, ShapeDef *def, CompoundData *compound) @cname("b3CreateCompoundShape");
extern fn void destroyShape(ShapeId shapeId, bool updateBodyMass) @cname("b3DestroyShape");
extern fn bool shape_IsValid(ShapeId id) @cname("b3Shape_IsValid");
extern fn ShapeType shape_GetType(ShapeId shapeId) @cname("b3Shape_GetType");
extern fn BodyId shape_GetBody(ShapeId shapeId) @cname("b3Shape_GetBody");
extern fn WorldId shape_GetWorld(ShapeId shapeId) @cname("b3Shape_GetWorld");
extern fn bool shape_IsSensor(ShapeId shapeId) @cname("b3Shape_IsSensor");
extern fn void shape_SetName(ShapeId shapeId, ZString name) @cname("b3Shape_SetName");
extern fn ZString shape_GetName(ShapeId shapeId) @cname("b3Shape_GetName");
extern fn void shape_SetUserData(ShapeId shapeId, void *userData) @cname("b3Shape_SetUserData");
extern fn void* shape_GetUserData(ShapeId shapeId) @cname("b3Shape_GetUserData");
extern fn void shape_SetDensity(ShapeId shapeId, float density, bool updateBodyMass) @cname("b3Shape_SetDensity");
extern fn float shape_GetDensity(ShapeId shapeId) @cname("b3Shape_GetDensity");
extern fn void shape_SetFriction(ShapeId shapeId, float friction) @cname("b3Shape_SetFriction");
extern fn float shape_GetFriction(ShapeId shapeId) @cname("b3Shape_GetFriction");
extern fn void shape_SetRestitution(ShapeId shapeId, float restitution) @cname("b3Shape_SetRestitution");
extern fn float shape_GetRestitution(ShapeId shapeId) @cname("b3Shape_GetRestitution");
extern fn void shape_SetSurfaceMaterial(ShapeId shapeId, SurfaceMaterial surfaceMaterial) @cname("b3Shape_SetSurfaceMaterial");
extern fn SurfaceMaterial shape_GetSurfaceMaterial(ShapeId shapeId) @cname("b3Shape_GetSurfaceMaterial");
extern fn int shape_GetMeshMaterialCount(ShapeId shapeId) @cname("b3Shape_GetMeshMaterialCount");
extern fn void shape_SetMeshMaterial(ShapeId shapeId, SurfaceMaterial surfaceMaterial, int index) @cname("b3Shape_SetMeshMaterial");
extern fn SurfaceMaterial shape_GetMeshSurfaceMaterial(ShapeId shapeId, int index) @cname("b3Shape_GetMeshSurfaceMaterial");
extern fn Filter shape_GetFilter(ShapeId shapeId) @cname("b3Shape_GetFilter");
extern fn void shape_SetFilter(ShapeId shapeId, Filter filter, bool invokeContacts) @cname("b3Shape_SetFilter");
extern fn void shape_EnableSensorEvents(ShapeId shapeId, bool flag) @cname("b3Shape_EnableSensorEvents");
extern fn bool shape_AreSensorEventsEnabled(ShapeId shapeId) @cname("b3Shape_AreSensorEventsEnabled");
extern fn void shape_EnableContactEvents(ShapeId shapeId, bool flag) @cname("b3Shape_EnableContactEvents");
extern fn bool shape_AreContactEventsEnabled(ShapeId shapeId) @cname("b3Shape_AreContactEventsEnabled");
extern fn void shape_EnablePreSolveEvents(ShapeId shapeId, bool flag) @cname("b3Shape_EnablePreSolveEvents");
extern fn bool shape_ArePreSolveEventsEnabled(ShapeId shapeId) @cname("b3Shape_ArePreSolveEventsEnabled");
extern fn void shape_EnableHitEvents(ShapeId shapeId, bool flag) @cname("b3Shape_EnableHitEvents");
extern fn bool shape_AreHitEventsEnabled(ShapeId shapeId) @cname("b3Shape_AreHitEventsEnabled");
extern fn WorldCastOutput shape_RayCast(ShapeId shapeId, Pos origin, Vec3 translation) @cname("b3Shape_RayCast");
extern fn Sphere shape_GetSphere(ShapeId shapeId) @cname("b3Shape_GetSphere");
extern fn Capsule shape_GetCapsule(ShapeId shapeId) @cname("b3Shape_GetCapsule");
extern fn HullData* shape_GetHull(ShapeId shapeId) @cname("b3Shape_GetHull");
extern fn Mesh shape_GetMesh(ShapeId shapeId) @cname("b3Shape_GetMesh");
extern fn HeightFieldData* shape_GetHeightField(ShapeId shapeId) @cname("b3Shape_GetHeightField");
extern fn void shape_SetSphere(ShapeId shapeId, Sphere *sphere) @cname("b3Shape_SetSphere");
extern fn void shape_SetCapsule(ShapeId shapeId, Capsule *capsule) @cname("b3Shape_SetCapsule");
extern fn void shape_SetHull(ShapeId shapeId, HullData *hull) @cname("b3Shape_SetHull");
extern fn void shape_SetMesh(ShapeId shapeId, MeshData *meshData, Vec3 scale) @cname("b3Shape_SetMesh");
extern fn int shape_GetContactCapacity(ShapeId shapeId) @cname("b3Shape_GetContactCapacity");
extern fn int shape_GetContactData(ShapeId shapeId, ContactData *contactData, int capacity) @cname("b3Shape_GetContactData");
extern fn int shape_GetSensorCapacity(ShapeId shapeId) @cname("b3Shape_GetSensorCapacity");
extern fn int shape_GetSensorData(ShapeId shapeId, ShapeId *visitorIds, int capacity) @cname("b3Shape_GetSensorData");
extern fn Aabb shape_GetAABB(ShapeId shapeId) @cname("b3Shape_GetAABB");
extern fn MassData shape_ComputeMassData(ShapeId shapeId) @cname("b3Shape_ComputeMassData");
extern fn Vec3 shape_GetClosestPoint(ShapeId shapeId, Vec3 target) @cname("b3Shape_GetClosestPoint");
extern fn void shape_ApplyWind(ShapeId shapeId, Vec3 wind, float drag, float lift, float maxSpeed, bool wake) @cname("b3Shape_ApplyWind");
extern fn void destroyJoint(JointId jointId, bool wakeAttached) @cname("b3DestroyJoint");
extern fn bool joint_IsValid(JointId id) @cname("b3Joint_IsValid");
extern fn JointType joint_GetType(JointId jointId) @cname("b3Joint_GetType");
extern fn BodyId joint_GetBodyA(JointId jointId) @cname("b3Joint_GetBodyA");
extern fn BodyId joint_GetBodyB(JointId jointId) @cname("b3Joint_GetBodyB");
extern fn WorldId joint_GetWorld(JointId jointId) @cname("b3Joint_GetWorld");
extern fn void joint_SetLocalFrameA(JointId jointId, Transform localFrame) @cname("b3Joint_SetLocalFrameA");
extern fn Transform joint_GetLocalFrameA(JointId jointId) @cname("b3Joint_GetLocalFrameA");
extern fn void joint_SetLocalFrameB(JointId jointId, Transform localFrame) @cname("b3Joint_SetLocalFrameB");
extern fn Transform joint_GetLocalFrameB(JointId jointId) @cname("b3Joint_GetLocalFrameB");
extern fn void joint_SetCollideConnected(JointId jointId, bool shouldCollide) @cname("b3Joint_SetCollideConnected");
extern fn bool joint_GetCollideConnected(JointId jointId) @cname("b3Joint_GetCollideConnected");
extern fn void joint_SetUserData(JointId jointId, void *userData) @cname("b3Joint_SetUserData");
extern fn void* joint_GetUserData(JointId jointId) @cname("b3Joint_GetUserData");
extern fn void joint_WakeBodies(JointId jointId) @cname("b3Joint_WakeBodies");
extern fn Vec3 joint_GetConstraintForce(JointId jointId) @cname("b3Joint_GetConstraintForce");
extern fn Vec3 joint_GetConstraintTorque(JointId jointId) @cname("b3Joint_GetConstraintTorque");
extern fn float joint_GetLinearSeparation(JointId jointId) @cname("b3Joint_GetLinearSeparation");
extern fn float joint_GetAngularSeparation(JointId jointId) @cname("b3Joint_GetAngularSeparation");
extern fn void joint_SetConstraintTuning(JointId jointId, float hertz, float dampingRatio) @cname("b3Joint_SetConstraintTuning");
extern fn void joint_GetConstraintTuning(JointId jointId, float *hertz, float *dampingRatio) @cname("b3Joint_GetConstraintTuning");
extern fn void joint_SetForceThreshold(JointId jointId, float threshold) @cname("b3Joint_SetForceThreshold");
extern fn float joint_GetForceThreshold(JointId jointId) @cname("b3Joint_GetForceThreshold");
extern fn void joint_SetTorqueThreshold(JointId jointId, float threshold) @cname("b3Joint_SetTorqueThreshold");
extern fn float joint_GetTorqueThreshold(JointId jointId) @cname("b3Joint_GetTorqueThreshold");
extern fn JointId createParallelJoint(WorldId worldId, ParallelJointDef *def) @cname("b3CreateParallelJoint");
extern fn void parallelJoint_SetSpringHertz(JointId jointId, float hertz) @cname("b3ParallelJoint_SetSpringHertz");
extern fn void parallelJoint_SetSpringDampingRatio(JointId jointId, float dampingRatio) @cname("b3ParallelJoint_SetSpringDampingRatio");
extern fn float parallelJoint_GetSpringHertz(JointId jointId) @cname("b3ParallelJoint_GetSpringHertz");
extern fn float parallelJoint_GetSpringDampingRatio(JointId jointId) @cname("b3ParallelJoint_GetSpringDampingRatio");
extern fn void parallelJoint_SetMaxTorque(JointId jointId, float force) @cname("b3ParallelJoint_SetMaxTorque");
extern fn float parallelJoint_GetMaxTorque(JointId jointId) @cname("b3ParallelJoint_GetMaxTorque");
extern fn JointId createDistanceJoint(WorldId worldId, DistanceJointDef *def) @cname("b3CreateDistanceJoint");
extern fn void distanceJoint_SetLength(JointId jointId, float length) @cname("b3DistanceJoint_SetLength");
extern fn float distanceJoint_GetLength(JointId jointId) @cname("b3DistanceJoint_GetLength");
extern fn void distanceJoint_EnableSpring(JointId jointId, bool enableSpring) @cname("b3DistanceJoint_EnableSpring");
extern fn bool distanceJoint_IsSpringEnabled(JointId jointId) @cname("b3DistanceJoint_IsSpringEnabled");
extern fn void distanceJoint_SetSpringForceRange(JointId jointId, float lowerForce, float upperForce) @cname("b3DistanceJoint_SetSpringForceRange");
extern fn void distanceJoint_GetSpringForceRange(JointId jointId, float *lowerForce, float *upperForce) @cname("b3DistanceJoint_GetSpringForceRange");
extern fn void distanceJoint_SetSpringHertz(JointId jointId, float hertz) @cname("b3DistanceJoint_SetSpringHertz");
extern fn void distanceJoint_SetSpringDampingRatio(JointId jointId, float dampingRatio) @cname("b3DistanceJoint_SetSpringDampingRatio");
extern fn float distanceJoint_GetSpringHertz(JointId jointId) @cname("b3DistanceJoint_GetSpringHertz");
extern fn float distanceJoint_GetSpringDampingRatio(JointId jointId) @cname("b3DistanceJoint_GetSpringDampingRatio");
extern fn void distanceJoint_EnableLimit(JointId jointId, bool enableLimit) @cname("b3DistanceJoint_EnableLimit");
extern fn bool distanceJoint_IsLimitEnabled(JointId jointId) @cname("b3DistanceJoint_IsLimitEnabled");
extern fn void distanceJoint_SetLengthRange(JointId jointId, float minLength, float maxLength) @cname("b3DistanceJoint_SetLengthRange");
extern fn float distanceJoint_GetMinLength(JointId jointId) @cname("b3DistanceJoint_GetMinLength");
extern fn float distanceJoint_GetMaxLength(JointId jointId) @cname("b3DistanceJoint_GetMaxLength");
extern fn float distanceJoint_GetCurrentLength(JointId jointId) @cname("b3DistanceJoint_GetCurrentLength");
extern fn void distanceJoint_EnableMotor(JointId jointId, bool enableMotor) @cname("b3DistanceJoint_EnableMotor");
extern fn bool distanceJoint_IsMotorEnabled(JointId jointId) @cname("b3DistanceJoint_IsMotorEnabled");
extern fn void distanceJoint_SetMotorSpeed(JointId jointId, float motorSpeed) @cname("b3DistanceJoint_SetMotorSpeed");
extern fn float distanceJoint_GetMotorSpeed(JointId jointId) @cname("b3DistanceJoint_GetMotorSpeed");
extern fn void distanceJoint_SetMaxMotorForce(JointId jointId, float force) @cname("b3DistanceJoint_SetMaxMotorForce");
extern fn float distanceJoint_GetMaxMotorForce(JointId jointId) @cname("b3DistanceJoint_GetMaxMotorForce");
extern fn float distanceJoint_GetMotorForce(JointId jointId) @cname("b3DistanceJoint_GetMotorForce");
extern fn JointId createMotorJoint(WorldId worldId, MotorJointDef *def) @cname("b3CreateMotorJoint");
extern fn void motorJoint_SetLinearVelocity(JointId jointId, Vec3 velocity) @cname("b3MotorJoint_SetLinearVelocity");
extern fn Vec3 motorJoint_GetLinearVelocity(JointId jointId) @cname("b3MotorJoint_GetLinearVelocity");
extern fn void motorJoint_SetAngularVelocity(JointId jointId, Vec3 velocity) @cname("b3MotorJoint_SetAngularVelocity");
extern fn Vec3 motorJoint_GetAngularVelocity(JointId jointId) @cname("b3MotorJoint_GetAngularVelocity");
extern fn void motorJoint_SetMaxVelocityForce(JointId jointId, float maxForce) @cname("b3MotorJoint_SetMaxVelocityForce");
extern fn float motorJoint_GetMaxVelocityForce(JointId jointId) @cname("b3MotorJoint_GetMaxVelocityForce");
extern fn void motorJoint_SetMaxVelocityTorque(JointId jointId, float maxTorque) @cname("b3MotorJoint_SetMaxVelocityTorque");
extern fn float motorJoint_GetMaxVelocityTorque(JointId jointId) @cname("b3MotorJoint_GetMaxVelocityTorque");
extern fn void motorJoint_SetLinearHertz(JointId jointId, float hertz) @cname("b3MotorJoint_SetLinearHertz");
extern fn float motorJoint_GetLinearHertz(JointId jointId) @cname("b3MotorJoint_GetLinearHertz");
extern fn void motorJoint_SetLinearDampingRatio(JointId jointId, float damping) @cname("b3MotorJoint_SetLinearDampingRatio");
extern fn float motorJoint_GetLinearDampingRatio(JointId jointId) @cname("b3MotorJoint_GetLinearDampingRatio");
extern fn void motorJoint_SetAngularHertz(JointId jointId, float hertz) @cname("b3MotorJoint_SetAngularHertz");
extern fn float motorJoint_GetAngularHertz(JointId jointId) @cname("b3MotorJoint_GetAngularHertz");
extern fn void motorJoint_SetAngularDampingRatio(JointId jointId, float damping) @cname("b3MotorJoint_SetAngularDampingRatio");
extern fn float motorJoint_GetAngularDampingRatio(JointId jointId) @cname("b3MotorJoint_GetAngularDampingRatio");
extern fn void motorJoint_SetMaxSpringForce(JointId jointId, float maxForce) @cname("b3MotorJoint_SetMaxSpringForce");
extern fn float motorJoint_GetMaxSpringForce(JointId jointId) @cname("b3MotorJoint_GetMaxSpringForce");
extern fn void motorJoint_SetMaxSpringTorque(JointId jointId, float maxTorque) @cname("b3MotorJoint_SetMaxSpringTorque");
extern fn float motorJoint_GetMaxSpringTorque(JointId jointId) @cname("b3MotorJoint_GetMaxSpringTorque");
extern fn JointId createFilterJoint(WorldId worldId, FilterJointDef *def) @cname("b3CreateFilterJoint");
extern fn JointId createPrismaticJoint(WorldId worldId, PrismaticJointDef *def) @cname("b3CreatePrismaticJoint");
extern fn void prismaticJoint_EnableSpring(JointId jointId, bool enableSpring) @cname("b3PrismaticJoint_EnableSpring");
extern fn bool prismaticJoint_IsSpringEnabled(JointId jointId) @cname("b3PrismaticJoint_IsSpringEnabled");
extern fn void prismaticJoint_SetSpringHertz(JointId jointId, float hertz) @cname("b3PrismaticJoint_SetSpringHertz");
extern fn float prismaticJoint_GetSpringHertz(JointId jointId) @cname("b3PrismaticJoint_GetSpringHertz");
extern fn void prismaticJoint_SetSpringDampingRatio(JointId jointId, float dampingRatio) @cname("b3PrismaticJoint_SetSpringDampingRatio");
extern fn float prismaticJoint_GetSpringDampingRatio(JointId jointId) @cname("b3PrismaticJoint_GetSpringDampingRatio");
extern fn void prismaticJoint_SetTargetTranslation(JointId jointId, float targetTranslation) @cname("b3PrismaticJoint_SetTargetTranslation");
extern fn float prismaticJoint_GetTargetTranslation(JointId jointId) @cname("b3PrismaticJoint_GetTargetTranslation");
extern fn void prismaticJoint_EnableLimit(JointId jointId, bool enableLimit) @cname("b3PrismaticJoint_EnableLimit");
extern fn bool prismaticJoint_IsLimitEnabled(JointId jointId) @cname("b3PrismaticJoint_IsLimitEnabled");
extern fn float prismaticJoint_GetLowerLimit(JointId jointId) @cname("b3PrismaticJoint_GetLowerLimit");
extern fn float prismaticJoint_GetUpperLimit(JointId jointId) @cname("b3PrismaticJoint_GetUpperLimit");
extern fn void prismaticJoint_SetLimits(JointId jointId, float lower, float upper) @cname("b3PrismaticJoint_SetLimits");
extern fn void prismaticJoint_EnableMotor(JointId jointId, bool enableMotor) @cname("b3PrismaticJoint_EnableMotor");
extern fn bool prismaticJoint_IsMotorEnabled(JointId jointId) @cname("b3PrismaticJoint_IsMotorEnabled");
extern fn void prismaticJoint_SetMotorSpeed(JointId jointId, float motorSpeed) @cname("b3PrismaticJoint_SetMotorSpeed");
extern fn float prismaticJoint_GetMotorSpeed(JointId jointId) @cname("b3PrismaticJoint_GetMotorSpeed");
extern fn void prismaticJoint_SetMaxMotorForce(JointId jointId, float force) @cname("b3PrismaticJoint_SetMaxMotorForce");
extern fn float prismaticJoint_GetMaxMotorForce(JointId jointId) @cname("b3PrismaticJoint_GetMaxMotorForce");
extern fn float prismaticJoint_GetMotorForce(JointId jointId) @cname("b3PrismaticJoint_GetMotorForce");
extern fn float prismaticJoint_GetTranslation(JointId jointId) @cname("b3PrismaticJoint_GetTranslation");
extern fn float prismaticJoint_GetSpeed(JointId jointId) @cname("b3PrismaticJoint_GetSpeed");
extern fn JointId createRevoluteJoint(WorldId worldId, RevoluteJointDef *def) @cname("b3CreateRevoluteJoint");
extern fn void revoluteJoint_EnableSpring(JointId jointId, bool enableSpring) @cname("b3RevoluteJoint_EnableSpring");
extern fn bool revoluteJoint_IsSpringEnabled(JointId jointId) @cname("b3RevoluteJoint_IsSpringEnabled");
extern fn void revoluteJoint_SetSpringHertz(JointId jointId, float hertz) @cname("b3RevoluteJoint_SetSpringHertz");
extern fn float revoluteJoint_GetSpringHertz(JointId jointId) @cname("b3RevoluteJoint_GetSpringHertz");
extern fn void revoluteJoint_SetSpringDampingRatio(JointId jointId, float dampingRatio) @cname("b3RevoluteJoint_SetSpringDampingRatio");
extern fn float revoluteJoint_GetSpringDampingRatio(JointId jointId) @cname("b3RevoluteJoint_GetSpringDampingRatio");
extern fn void revoluteJoint_SetTargetAngle(JointId jointId, float targetRadians) @cname("b3RevoluteJoint_SetTargetAngle");
extern fn float revoluteJoint_GetTargetAngle(JointId jointId) @cname("b3RevoluteJoint_GetTargetAngle");
extern fn float revoluteJoint_GetAngle(JointId jointId) @cname("b3RevoluteJoint_GetAngle");
extern fn void revoluteJoint_EnableLimit(JointId jointId, bool enableLimit) @cname("b3RevoluteJoint_EnableLimit");
extern fn bool revoluteJoint_IsLimitEnabled(JointId jointId) @cname("b3RevoluteJoint_IsLimitEnabled");
extern fn float revoluteJoint_GetLowerLimit(JointId jointId) @cname("b3RevoluteJoint_GetLowerLimit");
extern fn float revoluteJoint_GetUpperLimit(JointId jointId) @cname("b3RevoluteJoint_GetUpperLimit");
extern fn void revoluteJoint_SetLimits(JointId jointId, float lowerLimitRadians, float upperLimitRadians) @cname("b3RevoluteJoint_SetLimits");
extern fn void revoluteJoint_EnableMotor(JointId jointId, bool enableMotor) @cname("b3RevoluteJoint_EnableMotor");
extern fn bool revoluteJoint_IsMotorEnabled(JointId jointId) @cname("b3RevoluteJoint_IsMotorEnabled");
extern fn void revoluteJoint_SetMotorSpeed(JointId jointId, float motorSpeed) @cname("b3RevoluteJoint_SetMotorSpeed");
extern fn float revoluteJoint_GetMotorSpeed(JointId jointId) @cname("b3RevoluteJoint_GetMotorSpeed");
extern fn float revoluteJoint_GetMotorTorque(JointId jointId) @cname("b3RevoluteJoint_GetMotorTorque");
extern fn void revoluteJoint_SetMaxMotorTorque(JointId jointId, float torque) @cname("b3RevoluteJoint_SetMaxMotorTorque");
extern fn float revoluteJoint_GetMaxMotorTorque(JointId jointId) @cname("b3RevoluteJoint_GetMaxMotorTorque");
extern fn JointId createSphericalJoint(WorldId worldId, SphericalJointDef *def) @cname("b3CreateSphericalJoint");
extern fn void sphericalJoint_EnableConeLimit(JointId jointId, bool enableLimit) @cname("b3SphericalJoint_EnableConeLimit");
extern fn bool sphericalJoint_IsConeLimitEnabled(JointId jointId) @cname("b3SphericalJoint_IsConeLimitEnabled");
extern fn float sphericalJoint_GetConeLimit(JointId jointId) @cname("b3SphericalJoint_GetConeLimit");
extern fn void sphericalJoint_SetConeLimit(JointId jointId, float angleRadians) @cname("b3SphericalJoint_SetConeLimit");
extern fn float sphericalJoint_GetConeAngle(JointId jointId) @cname("b3SphericalJoint_GetConeAngle");
extern fn void sphericalJoint_EnableTwistLimit(JointId jointId, bool enableLimit) @cname("b3SphericalJoint_EnableTwistLimit");
extern fn bool sphericalJoint_IsTwistLimitEnabled(JointId jointId) @cname("b3SphericalJoint_IsTwistLimitEnabled");
extern fn float sphericalJoint_GetLowerTwistLimit(JointId jointId) @cname("b3SphericalJoint_GetLowerTwistLimit");
extern fn float sphericalJoint_GetUpperTwistLimit(JointId jointId) @cname("b3SphericalJoint_GetUpperTwistLimit");
extern fn void sphericalJoint_SetTwistLimits(JointId jointId, float lowerLimitRadians, float upperLimitRadians) @cname("b3SphericalJoint_SetTwistLimits");
extern fn float sphericalJoint_GetTwistAngle(JointId jointId) @cname("b3SphericalJoint_GetTwistAngle");
extern fn void sphericalJoint_EnableSpring(JointId jointId, bool enableSpring) @cname("b3SphericalJoint_EnableSpring");
extern fn bool sphericalJoint_IsSpringEnabled(JointId jointId) @cname("b3SphericalJoint_IsSpringEnabled");
extern fn void sphericalJoint_SetSpringHertz(JointId jointId, float hertz) @cname("b3SphericalJoint_SetSpringHertz");
extern fn float sphericalJoint_GetSpringHertz(JointId jointId) @cname("b3SphericalJoint_GetSpringHertz");
extern fn void sphericalJoint_SetSpringDampingRatio(JointId jointId, float dampingRatio) @cname("b3SphericalJoint_SetSpringDampingRatio");
extern fn float sphericalJoint_GetSpringDampingRatio(JointId jointId) @cname("b3SphericalJoint_GetSpringDampingRatio");
extern fn void sphericalJoint_SetTargetRotation(JointId jointId, Quat targetRotation) @cname("b3SphericalJoint_SetTargetRotation");
extern fn Quat sphericalJoint_GetTargetRotation(JointId jointId) @cname("b3SphericalJoint_GetTargetRotation");
extern fn void sphericalJoint_EnableMotor(JointId jointId, bool enableMotor) @cname("b3SphericalJoint_EnableMotor");
extern fn bool sphericalJoint_IsMotorEnabled(JointId jointId) @cname("b3SphericalJoint_IsMotorEnabled");
extern fn void sphericalJoint_SetMotorVelocity(JointId jointId, Vec3 motorVelocity) @cname("b3SphericalJoint_SetMotorVelocity");
extern fn Vec3 sphericalJoint_GetMotorVelocity(JointId jointId) @cname("b3SphericalJoint_GetMotorVelocity");
extern fn Vec3 sphericalJoint_GetMotorTorque(JointId jointId) @cname("b3SphericalJoint_GetMotorTorque");
extern fn void sphericalJoint_SetMaxMotorTorque(JointId jointId, float torque) @cname("b3SphericalJoint_SetMaxMotorTorque");
extern fn float sphericalJoint_GetMaxMotorTorque(JointId jointId) @cname("b3SphericalJoint_GetMaxMotorTorque");
extern fn JointId createWeldJoint(WorldId worldId, WeldJointDef *def) @cname("b3CreateWeldJoint");
extern fn void weldJoint_SetLinearHertz(JointId jointId, float hertz) @cname("b3WeldJoint_SetLinearHertz");
extern fn float weldJoint_GetLinearHertz(JointId jointId) @cname("b3WeldJoint_GetLinearHertz");
extern fn void weldJoint_SetLinearDampingRatio(JointId jointId, float dampingRatio) @cname("b3WeldJoint_SetLinearDampingRatio");
extern fn float weldJoint_GetLinearDampingRatio(JointId jointId) @cname("b3WeldJoint_GetLinearDampingRatio");
extern fn void weldJoint_SetAngularHertz(JointId jointId, float hertz) @cname("b3WeldJoint_SetAngularHertz");
extern fn float weldJoint_GetAngularHertz(JointId jointId) @cname("b3WeldJoint_GetAngularHertz");
extern fn void weldJoint_SetAngularDampingRatio(JointId jointId, float dampingRatio) @cname("b3WeldJoint_SetAngularDampingRatio");
extern fn float weldJoint_GetAngularDampingRatio(JointId jointId) @cname("b3WeldJoint_GetAngularDampingRatio");
extern fn JointId createWheelJoint(WorldId worldId, WheelJointDef *def) @cname("b3CreateWheelJoint");
extern fn void wheelJoint_EnableSuspension(JointId jointId, bool flag) @cname("b3WheelJoint_EnableSuspension");
extern fn bool wheelJoint_IsSuspensionEnabled(JointId jointId) @cname("b3WheelJoint_IsSuspensionEnabled");
extern fn void wheelJoint_SetSuspensionHertz(JointId jointId, float hertz) @cname("b3WheelJoint_SetSuspensionHertz");
extern fn float wheelJoint_GetSuspensionHertz(JointId jointId) @cname("b3WheelJoint_GetSuspensionHertz");
extern fn void wheelJoint_SetSuspensionDampingRatio(JointId jointId, float dampingRatio) @cname("b3WheelJoint_SetSuspensionDampingRatio");
extern fn float wheelJoint_GetSuspensionDampingRatio(JointId jointId) @cname("b3WheelJoint_GetSuspensionDampingRatio");
extern fn void wheelJoint_EnableSuspensionLimit(JointId jointId, bool flag) @cname("b3WheelJoint_EnableSuspensionLimit");
extern fn bool wheelJoint_IsSuspensionLimitEnabled(JointId jointId) @cname("b3WheelJoint_IsSuspensionLimitEnabled");
extern fn float wheelJoint_GetLowerSuspensionLimit(JointId jointId) @cname("b3WheelJoint_GetLowerSuspensionLimit");
extern fn float wheelJoint_GetUpperSuspensionLimit(JointId jointId) @cname("b3WheelJoint_GetUpperSuspensionLimit");
extern fn void wheelJoint_SetSuspensionLimits(JointId jointId, float lower, float upper) @cname("b3WheelJoint_SetSuspensionLimits");
extern fn void wheelJoint_EnableSpinMotor(JointId jointId, bool flag) @cname("b3WheelJoint_EnableSpinMotor");
extern fn bool wheelJoint_IsSpinMotorEnabled(JointId jointId) @cname("b3WheelJoint_IsSpinMotorEnabled");
extern fn void wheelJoint_SetSpinMotorSpeed(JointId jointId, float speed) @cname("b3WheelJoint_SetSpinMotorSpeed");
extern fn float wheelJoint_GetSpinMotorSpeed(JointId jointId) @cname("b3WheelJoint_GetSpinMotorSpeed");
extern fn void wheelJoint_SetMaxSpinTorque(JointId jointId, float torque) @cname("b3WheelJoint_SetMaxSpinTorque");
extern fn float wheelJoint_GetMaxSpinTorque(JointId jointId) @cname("b3WheelJoint_GetMaxSpinTorque");
extern fn float wheelJoint_GetSpinSpeed(JointId jointId) @cname("b3WheelJoint_GetSpinSpeed");
extern fn float wheelJoint_GetSpinTorque(JointId jointId) @cname("b3WheelJoint_GetSpinTorque");
extern fn void wheelJoint_EnableSteering(JointId jointId, bool flag) @cname("b3WheelJoint_EnableSteering");
extern fn bool wheelJoint_IsSteeringEnabled(JointId jointId) @cname("b3WheelJoint_IsSteeringEnabled");
extern fn void wheelJoint_SetSteeringHertz(JointId jointId, float hertz) @cname("b3WheelJoint_SetSteeringHertz");
extern fn float wheelJoint_GetSteeringHertz(JointId jointId) @cname("b3WheelJoint_GetSteeringHertz");
extern fn void wheelJoint_SetSteeringDampingRatio(JointId jointId, float dampingRatio) @cname("b3WheelJoint_SetSteeringDampingRatio");
extern fn float wheelJoint_GetSteeringDampingRatio(JointId jointId) @cname("b3WheelJoint_GetSteeringDampingRatio");
extern fn void wheelJoint_SetMaxSteeringTorque(JointId jointId, float torque) @cname("b3WheelJoint_SetMaxSteeringTorque");
extern fn float wheelJoint_GetMaxSteeringTorque(JointId jointId) @cname("b3WheelJoint_GetMaxSteeringTorque");
extern fn void wheelJoint_EnableSteeringLimit(JointId jointId, bool flag) @cname("b3WheelJoint_EnableSteeringLimit");
extern fn bool wheelJoint_IsSteeringLimitEnabled(JointId jointId) @cname("b3WheelJoint_IsSteeringLimitEnabled");
extern fn float wheelJoint_GetLowerSteeringLimit(JointId jointId) @cname("b3WheelJoint_GetLowerSteeringLimit");
extern fn float wheelJoint_GetUpperSteeringLimit(JointId jointId) @cname("b3WheelJoint_GetUpperSteeringLimit");
extern fn void wheelJoint_SetSteeringLimits(JointId jointId, float lowerRadians, float upperRadians) @cname("b3WheelJoint_SetSteeringLimits");
extern fn void wheelJoint_SetTargetSteeringAngle(JointId jointId, float radians) @cname("b3WheelJoint_SetTargetSteeringAngle");
extern fn float wheelJoint_GetTargetSteeringAngle(JointId jointId) @cname("b3WheelJoint_GetTargetSteeringAngle");
extern fn float wheelJoint_GetSteeringAngle(JointId jointId) @cname("b3WheelJoint_GetSteeringAngle");
extern fn float wheelJoint_GetSteeringTorque(JointId jointId) @cname("b3WheelJoint_GetSteeringTorque");
extern fn bool contact_IsValid(ContactId id) @cname("b3Contact_IsValid");
extern fn ContactData contact_GetData(ContactId contactId) @cname("b3Contact_GetData");