# Mesh-Cloud-Rendering

A re-implementation of mesh cloud described in [Sea of Thieves: Tech Art and Shader Development](https://vimeo.com/326413164)  
![Rendering](/unity/Recordings/image_0000.png) 

Basically, it pre-compute occlusion lobe on mesh vertex and use it for real time shading.   
![Lobe](/unity/Recordings/lobe.png)  

A comparasion of ground truth and approximated shading:
Left: Houdini's cloudlight node, LeftMiddle: Per vertex raymarching ground truth. Middle: Approximation using occlusion lobe. RightMiddle: Lambert. Right: Combine occlusion lobe and lambert.
![Shading](/unity/Recordings/shading.png)  

After vertex shading, multiple pass of post-processing is employed to blur and distort the buffer, finally composite into background.

Here I didn't sculpt the cloud mesh by hand, instead I generate clouds with L-system in Houdini   
![cloud](/unity/Recordings/cloud-gen.png) 

Some renderings    
![1](/unity/Recordings/gif_animation_002.gif)   
![2](/unity/Recordings/gif_animation_003.gif)   
![3](/unity/Recordings/gif_animation_004.gif)   

# Requirement
Unity 2018.4

# Reference
[Sea of Thieves: Tech Art and Shader Development](https://vimeo.com/326413164)  
