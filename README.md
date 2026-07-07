# Box3D for C3
C3 bindings for [Box3D](https://github.com/erincatto/box3d), a 3D physics engine by @erincatto.  
I haven't done a lot of testing yet, so there might be issues. Report issues please ^^  
  
## Usage
Include box3d.c3 in your project and make sure to link against the box3d library.  
You can compile your C3 project with the following feature flags:  
```
	-D BOX3D_ENABLE_ASSERT
	-D BOX3D_ENABLE_VALIDATION
	-D BOX3D_DOUBLE_PRECISION
```