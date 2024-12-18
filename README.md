# Unspoken

This project builds upon the **Synaesthetic** art research project executed by the working group **Los Actantes**. The goal is to use Metal shaders to parametrize sound and render visual abstractions natively on Apple devices, including **iOS**, **iPadOS**, and **macOS**.

[Link to the Synaesthetic repository](https://github.com/fabiofranzese/Synaesthetic.git)

## Project Goals

The general aim is to explore ways of transferring rendered Metal shaders into the immersive space of **VisionOS**. The research focuses on finding methods to impact shaders interactively through **gestures** or **sound inputs**. The project has two potential end goals:

1. **Interactive Visuals Based on Sound Input**  
   Create a virtual environment that changes dynamically in response to sound input such as singing, speaking, yelling, or playing music. The shaders would evolve interactively, driven by the sound.

2. **Gesture-Driven Synthesizer-Like Interaction**  
   Develop an experience akin to a sound or music synthesizer. For example:
   - **Pinch and drag gestures** could allow users to modify shader parameters, mimicking the gestures of a music conductor.
   - Visual changes in the environment could generate corresponding **sound outputs**, creating a loop of interaction.

In this flow, the inputs and outputs can be modeled as either:
- **Sound input → Visual output**, or
- **Gesture input → Visual output → Sound output**.

## Current State

At present, the app only **displays the environment** without providing interactive controls to impact it. Development is severely limited due to the lack of access to a **Vision Pro** device, as the simulator does not support many features such as hand tracking.

### Experimenting with Shaders

You can manually experiment with shader parameters in `Shaders.metal` before building the app. Below are some recommendations:

#### Example: Modify the Value in the Noise Function
Try changing the value `3.0` in the following line of code to a range up to `20` to see how it affects the scenery.

```cpp
f = f * f * (3.0 - 2.0 * f);
```

Here’s the full noise function:

```cpp
float noise(float2 x) {
    float2 p = floor(x);
    float2 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash(p + float2(0.0, 0.0));
    float b = hash(p + float2(1.0, 0.0));
    float c = hash(p + float2(0.0, 1.0));
    float d = hash(p + float2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
```

#### Example: Adjust Amplitude in FBM
Try increasing the amplitude value to a range of `20` in the `fbm4` function:

```cpp
// Fractal Brownian Motion (FBM) with 4 octaves
float fbm4(float2 p) {
    float f = 0.0;
    float amplitude = 3.0;
    float2 mtx = float2(0.80, 0.60);

    for (int i = 0; i < 4; i++) {
        f += amplitude * (-1.0 + 2.0 * noise(p));
        p = float2(mtx.x, -mtx.y) * p * 2.02;
        amplitude *= 0.5;
    }
    return f / 0.9375;
}
```

### Working Title

The working title of the project is **Unspoken**, representing the ability to express what cannot be spoken in a new and creative way.
