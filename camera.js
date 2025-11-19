"use strict";

const clamp = (value, min, max) => Math.min(max, Math.max(min, value));

const vecNormalize = (v) => {
    const len = Math.hypot(v[0], v[1], v[2]);
    if (len === 0) return [0, 0, 0];
    return [v[0] / len, v[1] / len, v[2] / len];
};

const vecCross = (a, b) => ([
    a[1] * b[2] - a[2] * b[1],
    a[2] * b[0] - a[0] * b[2],
    a[0] * b[1] - a[1] * b[0]
]);

const scaleVec = (v, scalar) => [v[0] * scalar, v[1] * scalar, v[2] * scalar];

export class OrbitCamera {
    constructor(canvas, options) {
        this.canvas = canvas;
        this.target = options.target ?? [0, 0, 0];
        this.distance = options.distance ?? 10;
        this.yaw = options.yaw ?? 0;
        this.pitch = options.pitch ?? 0;
        this.fov = options.fov ?? (45 * Math.PI / 180);
        this.minDistance = options.minDistance ?? 1;
        this.maxDistance = options.maxDistance ?? 100;
        this.rotateSpeed = options.rotateSpeed ?? 0.005;
        this.zoomSpeed = options.zoomSpeed ?? 1.0;

        this._isDragging = false;
        this._lastMouseX = 0;
        this._lastMouseY = 0;
        this._listeners = new Set();

        this._bindEvents();
    }

    onChange(callback) {
        this._listeners.add(callback);
        return () => this._listeners.delete(callback);
    }

    _notifyChange() {
        this._listeners.forEach((cb) => cb());
    }

    _bindEvents() {
        this.canvas.addEventListener("mousedown", (e) => {
            this._isDragging = true;
            this._lastMouseX = e.clientX;
            this._lastMouseY = e.clientY;
        });

        window.addEventListener("mouseup", () => {
            this._isDragging = false;
        });

        window.addEventListener("mousemove", (e) => {
            if (!this._isDragging) return;
            const dx = e.clientX - this._lastMouseX;
            const dy = e.clientY - this._lastMouseY;
            this._lastMouseX = e.clientX;
            this._lastMouseY = e.clientY;
            this.yaw += dx * this.rotateSpeed;
            const pitchLimit = Math.PI / 2 - 0.05;
            this.pitch = clamp(this.pitch - dy * this.rotateSpeed, -pitchLimit, pitchLimit);
            this._notifyChange();
        });

        this.canvas.addEventListener("wheel", (e) => {
            e.preventDefault();
            this.distance *= Math.exp(e.deltaY * 0.001 * this.zoomSpeed);
            this.distance = clamp(this.distance, this.minDistance, this.maxDistance);
            this._notifyChange();
        }, { passive: false });
    }

    getBasis(width, height) {
        const dir = [
            Math.cos(this.pitch) * Math.sin(this.yaw),
            Math.sin(this.pitch),
            Math.cos(this.pitch) * Math.cos(this.yaw)
        ];
        const position = [
            this.target[0] + dir[0] * this.distance,
            this.target[1] + dir[1] * this.distance,
            this.target[2] + dir[2] * this.distance
        ];
        const forward = vecNormalize([
            this.target[0] - position[0],
            this.target[1] - position[1],
            this.target[2] - position[2]
        ]);
        let right = vecNormalize(vecCross(forward, [0, 1, 0]));
        if (Math.abs(right[0]) + Math.abs(right[1]) + Math.abs(right[2]) < 1e-5) {
            right = vecNormalize(vecCross(forward, [0, 0, 1]));
        }
        const up = vecNormalize(vecCross(right, forward));

        const tanFov = Math.tan(this.fov * 0.5);
        const aspect = width / height;

        return {
            position,
            forward,
            right: scaleVec(right, tanFov * aspect),
            up: scaleVec(up, tanFov)
        };
    }
}
