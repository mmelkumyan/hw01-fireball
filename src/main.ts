import {vec3} from 'gl-matrix';
import Stats from 'stats-js';
import * as DAT from 'dat.gui';
import Icosphere from './geometry/Icosphere';
import Square from './geometry/Square';
import OpenGLRenderer from './rendering/gl/OpenGLRenderer';
import Camera from './Camera';
import {setGL} from './globals';
import ShaderProgram, {Shader} from './rendering/gl/ShaderProgram';

import fireballVertSource from './shaders/fireball-vert.glsl';
import fireballFragSource from './shaders/fireball-frag.glsl';

import backgroundVertSource from './shaders/background-vert.glsl';
import backgroundFragSource from './shaders/background-frag.glsl';

const shaderParams = {
  u_TimeScale: 0.02,
  u_TrailWidthBias: 0.93,
  u_MinLength: 4.0,
  u_MaxLength: 7.0,
  u_PulseFreq: 0.06,
  u_Twists: 1.5,
  u_TwistSpeed: 0.06,
  u_NoiseScale: 1.0,
  u_Octaves: 3,
  u_ScrollSpeed: 1.5,
};

const intParams = new Set(['u_Octaves']);

const DEFAULTS = Object.freeze(Object.assign({}, shaderParams));

// Define an object with application parameters and button callbacks
// This will be referred to by dat.GUI's functions that add GUI elements.
const controls = {
  tesselations: 5,
  'Load Scene': loadScene, // A function pointer, essentially
  'Reset Defaults': resetDefaults,
};

let gui: DAT.GUI;

function resetDefaults() {
  Object.assign(shaderParams, DEFAULTS);
  gui.updateDisplay();
}

let icosphere: Icosphere;
let square: Square;
let prevTesselations: number = 5;
let time: GLfloat = 0;

function loadScene() {
  icosphere = new Icosphere(vec3.fromValues(0, 0, 0), 1, controls.tesselations);
  icosphere.create();
  square = new Square(vec3.fromValues(0, 0, 0));
  square.create();
}

function main() {
  // Initial display for framerate
  const stats = Stats();
  stats.setMode(0);
  stats.domElement.style.position = 'absolute';
  stats.domElement.style.left = '0px';
  stats.domElement.style.top = '0px';
  document.body.appendChild(stats.domElement);

  // Add controls to the gui
  gui = new DAT.GUI();
  gui.add(controls, 'tesselations', 0, 8).step(1);

  const shapeFolder = gui.addFolder('Shape');
  shapeFolder.add(shaderParams, 'u_TrailWidthBias', 0.5, 0.95).step(0.01).name('roundness');
  shapeFolder.add(shaderParams, 'u_MinLength', 1, 10).step(0.1).name('min length');
  shapeFolder.add(shaderParams, 'u_MaxLength', 1, 20).step(0.1).name('max length');
  shapeFolder.add(shaderParams, 'u_Twists', -6, 6).step(0.1).name('twists');
  shapeFolder.open();

  const animFolder = gui.addFolder('Animation');
  animFolder.add(shaderParams, 'u_TimeScale', 0, 0.2).step(0.005).name('noise speed');
  animFolder.add(shaderParams, 'u_PulseFreq', 0, 0.3).step(0.005).name('pulse rate');
  animFolder.add(shaderParams, 'u_TwistSpeed', 0, 0.2).step(0.001).name('twist speed');
  animFolder.open();

  const noiseFolder = gui.addFolder('Noise');
  noiseFolder.add(shaderParams, 'u_NoiseScale', 0.1, 4).step(0.05).name('scale');
  noiseFolder.add(shaderParams, 'u_Octaves', 1, 6).step(1).name('octaves');
  noiseFolder.open();

  const bgFolder = gui.addFolder('Background');
  bgFolder.add(shaderParams, 'u_ScrollSpeed', 0, 10).step(0.1).name('scroll speed');
  bgFolder.open();

  gui.add(controls, 'Load Scene');
  gui.add(controls, 'Reset Defaults');

  // get canvas and webgl context
  const canvas = <HTMLCanvasElement> document.getElementById('canvas');
  const gl = <WebGL2RenderingContext> canvas.getContext('webgl2');
  if (!gl) {
    alert('WebGL 2 not supported!');
  }
  // `setGL` is a function imported above which sets the value of `gl` in the `globals.ts` module.
  // Later, we can import `gl` from `globals.ts` to access it
  setGL(gl);

  // Initial call to load scene
  loadScene();

  const camera = new Camera(vec3.fromValues(0, 0, 5), vec3.fromValues(0, 0, 0));

  const renderer = new OpenGLRenderer(canvas);
  renderer.setClearColor(0.2, 0.2, 0.2, 1);
  gl.enable(gl.DEPTH_TEST);

  const fireball = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, fireballVertSource),
    new Shader(gl.FRAGMENT_SHADER, fireballFragSource),
  ]);

  const background = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, backgroundVertSource),
    new Shader(gl.FRAGMENT_SHADER, backgroundFragSource),
  ]);

  // This function will be called every frame
  function tick() {
    camera.update();
    stats.begin();
    gl.viewport(0, 0, window.innerWidth, window.innerHeight);
    renderer.clear();
    if(controls.tesselations != prevTesselations)
    {
      prevTesselations = controls.tesselations;
      icosphere = new Icosphere(vec3.fromValues(0, 0, 0), 1, prevTesselations);
      icosphere.create();
    }

    // Render background
    renderer.renderBackground(camera, background, square, time, shaderParams, intParams);
    // Render fireball
    renderer.render(camera, fireball, [
      icosphere,
    ], time++, shaderParams, intParams);
    stats.end();


    // Tell the browser to call `tick` again whenever it renders a new frame
    requestAnimationFrame(tick);
  }

  window.addEventListener('resize', function() {
    renderer.setSize(window.innerWidth, window.innerHeight);
    camera.setAspectRatio(window.innerWidth / window.innerHeight);
    camera.updateProjectionMatrix();
  }, false);

  renderer.setSize(window.innerWidth, window.innerHeight);
  camera.setAspectRatio(window.innerWidth / window.innerHeight);
  camera.updateProjectionMatrix();

  // Start the render loop
  tick();
}

main();
