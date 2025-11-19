"use strict";

export const MAT_DIFFUSE = 0;
export const MAT_MIRROR = 1;
export const MAT_GLASS = 2;

export const sceneBoxes = [
    { min: [-0.5, 0.0, 0.0], max: [0.0, 81.6, 170.0], albedo: [0.75, 0.25, 0.25], emission: [0.0, 0.0, 0.0], material: MAT_DIFFUSE },
    { min: [100.0, 0.0, 0.0], max: [100.5, 81.6, 170.0], albedo: [0.25, 0.25, 0.75], emission: [0.0, 0.0, 0.0], material: MAT_DIFFUSE },
    { min: [0.0, 0.0, -0.5], max: [100.0, 81.6, 0.0], albedo: [0.75, 0.75, 0.75], emission: [0.0, 0.0, 0.0], material: MAT_DIFFUSE },
    { min: [0.0, -0.5, 0.0], max: [100.0, 0.0, 170.0], albedo: [0.75, 0.75, 0.75], emission: [0.0, 0.0, 0.0], material: MAT_DIFFUSE },
    { min: [0.0, 81.6, 0.0], max: [100.0, 82.1, 170.0], albedo: [0.75, 0.75, 0.75], emission: [0.0, 0.0, 0.0], material: MAT_DIFFUSE },
    { min: [35.0, 81.0, 60.0], max: [65.0, 82.1, 100.0], albedo: [0.0, 0.0, 0.0], emission: [1.0, 1.0, 1.0], material: MAT_DIFFUSE },
    { min: [50.0, 0.0, 40.0], max: [80.0, 40.0, 60.0], albedo: [0.85, 0.85, 0.85], emission: [0.0, 0.0, 0.0], material: MAT_MIRROR }
];

export const sceneSpheres = [
    { center: [27.0, 16.5, 47.0], radius: 16.5, albedo: [0.999, 0.999, 0.999], emission: [0.0, 0.0, 0.0], material: MAT_MIRROR },
    { center: [53.0, 16.5, 98.0], radius: 16.5, albedo: [0.999, 0.999, 0.999], emission: [0.0, 0.0, 0.0], material: MAT_GLASS }
];

export const NUM_BOXES = sceneBoxes.length;
export const NUM_SPHERES = sceneSpheres.length;

export function buildSceneUniformBuffers(boxes = sceneBoxes, spheres = sceneSpheres) {
    const boxMinCorner = new Float32Array(boxes.length * 4);
    const boxMaxCorner = new Float32Array(boxes.length * 4);
    const boxAlbedo = new Float32Array(boxes.length * 4);
    const boxEmission = new Float32Array(boxes.length * 4);
    const boxMaterial = new Int32Array(boxes.length);

    boxes.forEach((box, i) => {
        const offset = i * 4;
        boxMinCorner.set([box.min[0], box.min[1], box.min[2], 0.0], offset);
        boxMaxCorner.set([box.max[0], box.max[1], box.max[2], 0.0], offset);
        boxAlbedo.set([box.albedo[0], box.albedo[1], box.albedo[2], 0.0], offset);
        boxEmission.set([box.emission[0], box.emission[1], box.emission[2], 0.0], offset);
        boxMaterial[i] = box.material;
    });

    const sphereCenterRadius = new Float32Array(spheres.length * 4);
    const sphereAlbedo = new Float32Array(spheres.length * 4);
    const sphereEmission = new Float32Array(spheres.length * 4);
    const sphereMaterial = new Int32Array(spheres.length);

    spheres.forEach((sphere, i) => {
        const offset = i * 4;
        sphereCenterRadius.set([sphere.center[0], sphere.center[1], sphere.center[2], sphere.radius], offset);
        sphereAlbedo.set([sphere.albedo[0], sphere.albedo[1], sphere.albedo[2], 0.0], offset);
        sphereEmission.set([sphere.emission[0], sphere.emission[1], sphere.emission[2], 0.0], offset);
        sphereMaterial[i] = sphere.material;
    });

    return {
        uBoxMinCorner: boxMinCorner,
        uBoxMaxCorner: boxMaxCorner,
        uBoxAlbedo: boxAlbedo,
        uBoxEmission: boxEmission,
        uBoxMaterial: boxMaterial,
        uSphereCenterRadius: sphereCenterRadius,
        uSphereAlbedo: sphereAlbedo,
        uSphereEmission: sphereEmission,
        uSphereMaterial: sphereMaterial
    };
}
