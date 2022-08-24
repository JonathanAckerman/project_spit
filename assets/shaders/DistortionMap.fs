#version 330

in vec2 fragTexCoord;

uniform sampler2D waterSampler;
uniform sampler2D distortionSampler;
uniform vec2 distortionOffset;

out vec4 finalColor;

void main()
{
    vec4 distortionTexel = texture(distortionSampler, fragTexCoord + distortionOffset/800);
    float grayValue = distortionTexel.x / 255.0; // assumes r=g=b
    float scale = 20.0;
    float offsetScalar = (2 * grayValue - 1) * scale;
    vec2 offset = vec2(20.0, 20.0) + vec2(offsetScalar, offsetScalar);
    vec2 directionOffset = vec2(distortionOffset.x/600, -distortionOffset.y/600);
    finalColor = texture(waterSampler, fragTexCoord + directionOffset + offset);
}