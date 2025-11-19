import { OrbitCamera } from "./camera.js";
import { sceneBoxes, sceneSpheres, buildSceneUniformBuffers } from "./scene.js";

async function loadText(url) {
    const res = await fetch(url);
    return await res.text();
}

function createFullscreenQuad(gl) {
    const vao = gl.createVertexArray();
    gl.bindVertexArray(vao);

    const quadVerts = new Float32Array([
        -1, -1,
         1, -1,
        -1,  1,
         1,  1
    ]);

    const quadBuffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, quadBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, quadVerts, gl.STATIC_DRAW);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);
}

function createPingPongTargets(gl, width, height) {
    const createTexture = () => twgl.createTexture(gl, {
        width,
        height,
        format: gl.RGBA,
        type: gl.FLOAT,
        internalFormat: gl.RGBA32F,
        minMag: gl.NEAREST,
        wrap: gl.CLAMP_TO_EDGE
    });

    const texA = createTexture();
    const texB = createTexture();

    const makeFbo = (texture) => twgl.createFramebufferInfo(gl, [
        { attachmentPoint: gl.COLOR_ATTACHMENT0, attachment: texture }
    ], width, height);

    return {
        read: makeFbo(texA),
        write: makeFbo(texB)
    };
}

function clearFbo(gl, framebuffer) {
    gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);
    gl.clearColor(0, 0, 0, 1);
    gl.clear(gl.COLOR_BUFFER_BIT);
}

async function main() {
    const canvas = document.querySelector("#canvasgl");
    const gl = canvas.getContext("webgl2");
    if (!gl) throw new Error("WebGL2 not supported");

    const ext = gl.getExtension("EXT_color_buffer_float");
    if (!ext) throw new Error("EXT_color_buffer_float not supported");

    gl.viewport(0, 0, canvas.width, canvas.height);

    const vertSrc = await loadText("shaders/vertQuad.glsl");
    const fragSrc = await loadText("shaders/fragRaytrace.glsl");
    const programInfo = twgl.createProgramInfo(gl, [vertSrc, fragSrc]);

    createFullscreenQuad(gl);

    let { read: readFbi, write: writeFbi } = createPingPongTargets(gl, canvas.width, canvas.height);
    clearFbo(gl, readFbi.framebuffer);
    clearFbo(gl, writeFbi.framebuffer);

    const camera = new OrbitCamera(canvas, {
        target: [50.0, 40.0, 81.6],
        distance: 120.0,
        yaw: 0.0,
        pitch: 0.12,
        fov: 90.0 * Math.PI / 180.0,
        minDistance: 50.0,
        maxDistance: 400.0,
        rotateSpeed: 0.005,
        zoomSpeed: 1.0
    });

    const sceneUniforms = buildSceneUniformBuffers(sceneBoxes, sceneSpheres);

    const uniforms = {
        iResolution: [canvas.width, canvas.height, canvas.width / canvas.height],
        iTime: 0,
        uSampleCount: 1,
        uPreviousFrame: null,
        uFrameCount: 0,
        uDisplayOnly: false,
        uCameraPos: [0, 0, 0],
        uCameraForward: [0, 0, -1],
        uCameraRight: [1, 0, 0],
        uCameraUp: [0, 1, 0],
        ...sceneUniforms
    };

    let frameCount = 0;
    let needsReset = false;

    const requestAccumulationReset = () => {
        needsReset = true;
    };

    const applyAccumulationReset = () => {
        if (!needsReset) return;
        clearFbo(gl, readFbi.framebuffer);
        clearFbo(gl, writeFbi.framebuffer);
        frameCount = 0;
        needsReset = false;
    };

    camera.onChange(requestAccumulationReset);

    function render(time) {
        applyAccumulationReset();

        const camBasis = camera.getBasis(canvas.width, canvas.height);
        uniforms.uCameraPos = camBasis.position;
        uniforms.uCameraForward = camBasis.forward;
        uniforms.uCameraRight = camBasis.right;
        uniforms.uCameraUp = camBasis.up;

        // Render to accumulation buffer
        gl.bindFramebuffer(gl.FRAMEBUFFER, writeFbi.framebuffer);
        gl.viewport(0, 0, canvas.width, canvas.height);

        uniforms.iTime = time;
        uniforms.uPreviousFrame = readFbi.attachments[0];
        uniforms.uFrameCount = frameCount;
        uniforms.uDisplayOnly = false;

        gl.useProgram(programInfo.program);
        twgl.setUniforms(programInfo, uniforms);
        gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);

        // Present to screen
        gl.bindFramebuffer(gl.FRAMEBUFFER, null);
        gl.viewport(0, 0, canvas.width, canvas.height);
        uniforms.uPreviousFrame = writeFbi.attachments[0];
        uniforms.uDisplayOnly = true;
        twgl.setUniforms(programInfo, uniforms);
        gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);

        [readFbi, writeFbi] = [writeFbi, readFbi];

        frameCount++;
        requestAnimationFrame(render);
    }

    requestAnimationFrame(render);
}

main();
