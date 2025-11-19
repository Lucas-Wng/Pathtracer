'use strict';

async function loadText(url) {
    const res = await fetch(url);
    return await res.text();
}

async function main() {
    const canvas = document.querySelector("#canvasgl");
    const gl = canvas.getContext("webgl2");
    if (!gl) throw new Error("WebGL2 not supported");

    gl.viewport(0, 0, canvas.width, canvas.height);

    const vertSrc = await loadText("shaders/vertQuad.glsl");
    const fragSrc = await loadText("shaders/fragRaytrace.glsl");

    const prog = twgl.createProgramInfo(gl, [vertSrc, fragSrc]);

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

    const uniforms = {
        iResolution: [canvas.width, canvas.height, canvas.width / canvas.height],
        iTime: 0,
        uSampleCount: 1
    };

    function render(t) {
        gl.viewport(0, 0, canvas.width, canvas.height);
        uniforms.iTime = t;

        gl.useProgram(prog.program);
        twgl.setUniforms(prog, uniforms);
        gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);

        requestAnimationFrame(render);
    }

    requestAnimationFrame(render);
}

main();
