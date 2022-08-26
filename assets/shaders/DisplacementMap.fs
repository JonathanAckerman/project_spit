#version 330

in vec2 fragTexCoord;

uniform sampler2D waterSampler;
uniform sampler2D displacementSampler;
uniform vec2 displacementOffset;

out vec4 finalColor;

void main()
{
    vec4 displacementTexel = texture(displacementSampler, fragTexCoord + displacementOffset/800);
    float grayValue = displacementTexel.x / 255.0; // assumes r=g=b
    float scale = 20.0;
    float offsetScalar = (2 * grayValue - 1) * scale;
    vec2 offset = vec2(20.0, 20.0) + vec2(offsetScalar, offsetScalar);
    vec2 directionOffset = vec2(displacementOffset.x/600, -displacementOffset.y/600);
    finalColor = texture(waterSampler, fragTexCoord + directionOffset + offset);
}