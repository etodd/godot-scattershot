# ScatterShot

A Godot 4 addon to randomly distribute meshes and decals in a scene in realtime.

<img width="1542" height="887" alt="ScatterShot in action" src="https://github.com/user-attachments/assets/5a226bb3-a78e-43b3-9459-304d26972364" />

An example of how fast it can redistribute instances:

https://github.com/user-attachments/assets/9cfe3d10-c0c6-4f34-a3b3-a19b321b39bd

## Usage

Create a `ScatterShotZone` node and assign it a `ScatterShotPattern` containing one or more `ScatterShotLayer` objects. Each layer distributes instances independent of the other layers. Each layer contains one or more "collections". A collection consists of either a `MeshLibrary` or a list of decal textures to distribute within the zone. If the `MeshLibrary` contains collision shapes, ScatterShot spawns a static physics body for each instance.

Once you're happy with the pattern, you can create other `ScatterShotZone` instances and assign them the same pattern.

To alter the density of instances in a certain area within a `ScatterShotZone`, create a `ScatterShotModulator`.

## Performance considerations

There are two main performance considerations: avoiding framerate stutters, and maintaining a high framerate.

### Avoiding stutters

ScatterShot avoids framerate stutters by creating and removing instances in "chunks", rather than all at once. ScatterShot creates one chunk per layer per frame. With the default chunk size of 16x16 grid cells, the maximum instances it can create in a single frame is 256, which is a good starting point to avoid stutters.

Since instances are created over time, you may notice them popping in, especially when the scene first loads, or when the camera teleports to a new location. You can increase the chunk size to force instances to be created faster, but beware of stutters.

### Maintaining high framerate

Each active chunk must be checked every frame, so it's important to limit the number of active chunks. The chunk count increases with longer view distance, and with smaller chunk size and grid scale.

### Large zones

There are no limits on the dimensions of a `ScatterShotZone`, and no performance penalty for large zones. Zones that are outside the view distance carry a fairly low performance cost.

### Modulators

`ScatterShotModulator` instances only incur a performance cost when a chunk is being created, and the cost is fairly low.

### MultiMesh

ScatterShot does not currently use `MultiMeshInstance3D` for several reasons:
- MultiMeshes can actually decrease performance because they prevent instances from being culled; either they are all drawn, or none. Because of this, you don't want to throw all the instances into a MultiMesh, you want to break them into chunks that can be culled.
- In addition, a MultiMesh can't have different variants; all the instances must be the same mesh.
- Because of this, at least for my use case (with many different mesh variations), I didn't think I could get enough instances grouped into a single MultiMesh to make it worthwhile performance-wise. And anyway, Godot is well-optimized for handling many individual mesh instances.
- But mostly, I just didn't feel like doing it. Maybe someone else will try!

## Acknowledgements

ScatterShot is heavily inspired by [ProtonScatter](https://github.com/HungryProton/scatter). The gizmo code is largely stolen directly from it.

Credit to [Christoph Peters](https://github.com/MomentsInGraphics) for 
the [blue noise texture](https://momentsingraphics.de/BlueNoise.html).

Credit to [Atrix256](https://github.com/Atrix256) for the [wonderful blog post](https://blog.demofox.org/2025/05/27/thresholding-modern-blue-noise-textures/) explaining the idea of thresholding a blue noise texture.
