// Lazy-loaded 3D model viewer. three.js (and the OpenCASCADE STEP importer) are
// large, so this is a SEPARATE esbuild entry kept out of application.js and
// pulled on demand by the certification--model-viewer Stimulus controller.
// renderModel() returns a dispose() that tears the WebGL scene down when the
// file preview is swapped out.
import * as THREE from "three";
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls.js";
import { STLLoader } from "three/examples/jsm/loaders/STLLoader.js";
import occtimportjs from "occt-import-js";
// The import makes esbuild emit + copy the wasm into builds/; but its baked URL
// is undigested, so at runtime we prefer the asset-pipeline URL the app passes in
// (occtWasmOverride) and fall back to the bundled one.
import occtWasmUrl from "occt-import-js/dist/occt-import-js.wasm";

let occtWasmOverride = null;
const SURFACE = 0xc7d2ff; // pale periwinkle, reads on the dark card

export async function renderModel({ canvas, src, format, wasmUrl }) {
  occtWasmOverride = wasmUrl || occtWasmOverride;
  const scene = new THREE.Scene();
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));

  const camera = new THREE.PerspectiveCamera(45, 1, 0.01, 1_000_000);
  scene.add(new THREE.HemisphereLight(0xffffff, 0x232338, 1.1));
  const key = new THREE.DirectionalLight(0xffffff, 1.4);
  key.position.set(1, 1, 1);
  scene.add(key);
  const fill = new THREE.DirectionalLight(0x99bbff, 0.5);
  fill.position.set(-1, 0.5, -1);
  scene.add(fill);

  const controls = new OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;

  const object = format === "stl" ? await loadStl(src) : await loadStep(src);
  scene.add(object);
  frameObject(object, camera, controls);

  const resize = () => {
    const w = canvas.clientWidth || 1;
    const h = canvas.clientHeight || 1;
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
  };
  const observer = new ResizeObserver(resize);
  observer.observe(canvas);
  resize();

  let alive = true;
  const loop = () => {
    if (!alive) return;
    controls.update();
    renderer.render(scene, camera);
    requestAnimationFrame(loop);
  };
  loop();

  return () => {
    alive = false;
    observer.disconnect();
    controls.dispose();
    renderer.dispose();
    scene.traverse((node) => {
      node.geometry?.dispose?.();
      node.material?.dispose?.();
    });
  };
}

async function loadStl(src) {
  const geometry = await new Promise((resolve, reject) =>
    new STLLoader().load(src, resolve, undefined, reject)
  );
  geometry.computeVertexNormals();
  return new THREE.Mesh(geometry, surfaceMaterial(SURFACE));
}

// One OpenCASCADE instance is enough for the session; the ~5 MB wasm loads on the
// first STEP file only.
let occtPromise;
async function loadStep(src) {
  occtPromise ||= occtimportjs({ locateFile: () => occtWasmOverride || occtWasmUrl });
  const occt = await occtPromise;

  const bytes = new Uint8Array(await (await fetch(src)).arrayBuffer());
  const result = occt.ReadStepFile(bytes, null);
  if (!result?.success || !result.meshes?.length) {
    throw new Error("couldn't parse this STEP file");
  }

  const group = new THREE.Group();
  for (const mesh of result.meshes) {
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute("position", new THREE.Float32BufferAttribute(mesh.attributes.position.array, 3));
    if (mesh.attributes.normal) {
      geometry.setAttribute("normal", new THREE.Float32BufferAttribute(mesh.attributes.normal.array, 3));
    }
    if (mesh.index) {
      geometry.setIndex(new THREE.BufferAttribute(new Uint32Array(mesh.index.array), 1));
    }
    if (!mesh.attributes.normal) geometry.computeVertexNormals();

    const color = mesh.color ? new THREE.Color(mesh.color[0], mesh.color[1], mesh.color[2]) : new THREE.Color(SURFACE);
    group.add(new THREE.Mesh(geometry, surfaceMaterial(color)));
  }
  return group;
}

function surfaceMaterial(color) {
  return new THREE.MeshStandardMaterial({ color, metalness: 0.15, roughness: 0.55 });
}

// Center the model at the origin and pull the camera back to frame its bounds.
function frameObject(object, camera, controls) {
  const box = new THREE.Box3().setFromObject(object);
  const size = box.getSize(new THREE.Vector3());
  const center = box.getCenter(new THREE.Vector3());
  object.position.sub(center);

  const radius = Math.max(size.x, size.y, size.z, 0.001) * 0.5;
  const distance = (radius / Math.sin((camera.fov * Math.PI) / 360)) * 1.6;
  camera.position.set(distance * 0.8, distance * 0.6, distance);
  camera.near = distance / 100;
  camera.far = distance * 100;
  camera.updateProjectionMatrix();
  controls.target.set(0, 0, 0);
  controls.update();
}
