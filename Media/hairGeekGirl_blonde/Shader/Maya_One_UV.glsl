//--------------------------------------------------------------------------------------
// Copyright 2014 Intel Corporation
// All Rights Reserved
//
// Permission is granted to use, copy, distribute and prepare derivative works of this
// software for any purpose and without fee, provided, that the above copyright notice
// and this statement appear in all copies.  Intel makes no representations about the
// suitability of this software for any purpose.  THIS SOFTWARE IS PROVIDED "AS IS."
// INTEL SPECIFICALLY DISCLAIMS ALL WARRANTIES, EXPRESS OR IMPLIED, AND ALL LIABILITY,
// INCLUDING CONSEQUENTIAL AND OTHER INDIRECT DAMAGES, FOR THE USE OF THIS SOFTWARE,
// INCLUDING LIABILITY FOR INFRINGEMENT OF ANY PROPRIETARY RIGHTS, AND INCLUDING THE
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  Intel does not
// assume any responsibility for any errors which may appear in this software nor any
// responsibility to update it.
//--------------------------------------------------------------------------------------
// Generated by ShaderGenerator.exe version 0.13
//--------------------------------------------------------------------------------------
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
// -------------------------------------
layout (std140, row_major) uniform cbPerModelValues
{
   mediump mat4 World;
   mediump mat4 NormalMatrix;
   mediump mat4 WorldViewProjection;
   mediump mat4 InverseWorld;
   mediump mat4 LightWorldViewProjection;
   mediump vec4 BoundingBoxCenterWorldSpace;
   mediump vec4 BoundingBoxHalfWorldSpace;
   mediump vec4 BoundingBoxCenterObjectSpace;
   mediump vec4 BoundingBoxHalfObjectSpace;
};

// -------------------------------------
layout (std140, row_major) uniform cbPerFrameValues
{
   mat4  View;
   mat4  InverseView;
   mat4  Projection;
   mat4  ViewProjection;
   vec4  AmbientColor;
   vec4  LightColor;
   vec4  LightDirection;
   vec4  EyePosition;
   vec4  TotalTimeInSeconds;
};

layout (std140, row_major) uniform cbExternals
{
	vec3 gBaseColor;
	float gAlpha;
	vec2 btScale;
	vec2 rmacScale;
        vec2 globalAOScale;
	float gRoughness;
	float gMetal;
	float gAmbient;
	float gCavity;
    vec3 gEmissive;
	
    bool   gUseBaseTexture;
    bool   gGammaCorrectBaseColor;
    bool   gUseNormalTexture;
    bool   gUseRMACTexture;
    bool   gUseRoughnessTexture;
    bool   gUseMetalTexture;
    bool   gUseAmbientTexture;
    bool   gUseCavityTexture;
    bool   gUseEnvironmentTexture;
    bool   gUseEmissiveTexture;
    bool   gUseGlobalAO;

};

#ifdef GLSL_VERTEX_SHADER

#define POSITION  0
#define NORMAL    1
#define BINORMAL  2
#define TANGENT   3
#define COLOR     4
#define TEXCOORD0 5
#define TEXCOORD1 6
// -------------------------------------
layout (location = POSITION)  in vec3 Position; // Projected position
layout (location = NORMAL)    in vec3 Normal;
layout (location = TEXCOORD0) in vec2 UV0;
#ifdef USE_UV1
layout (location = TEXCOORD1) in vec2 UV1;
#endif
layout (location = TANGENT) in vec3 Tangent;
layout (location = BINORMAL) in vec3 Binormal;
// -------------------------------------
out vec4 outPosition;
out vec3 outNormal;
out vec3 outTangent;
out vec3 outBinormal;

out vec2 outUV0;
out vec2 outUV1;
out vec3 outWorldPosition; // Object space position 
out vec3 outLightUV;

// -------------------------------------
void main( )
{
    outPosition      = vec4( Position, 1.0) * WorldViewProjection;
    outWorldPosition = (vec4( Position, 1.0) * World ).xyz;

    outNormal = (vec4(Normal, 1.0) * World).xyz;
	outTangent =  (vec4(Tangent, 1.0) * World).xyz;
	outBinormal =  (vec4(Binormal, 1.0) * World).xyz;
	outUV0 = UV0;
#ifdef USE_UV1
    outUV1 = UV1;
#else
    outUV1 = UV0;
#endif  
	outLightUV = (vec4( Position, 1.0) * LightWorldViewProjection).xyz;

    gl_Position = outPosition;
}

#endif //GLSL_VERTEX_SHADER


#ifdef GLSL_FRAGMENT_SHADER
// -------------------------------------
in mediump vec4 outPosition;
in mediump vec3 outNormal;
in mediump vec2 outUV0;
in mediump vec2 outUV1;
in mediump vec3 outWorldPosition; 
in mediump vec3 outLightUV;
in mediump vec3 outTangent;
in mediump vec3 outBinormal;
// -------------------------------------
uniform mediump sampler2D BaseTexture;
uniform mediump sampler2D NormalTexture;
uniform mediump sampler2D RMACTexture;
uniform mediump sampler2D RoughnessTexture;
uniform mediump sampler2D MetalTexture;
uniform mediump sampler2D AmbientTexture;
uniform mediump sampler2D GlobalAOTexture;
uniform mediump sampler2D CavityTexture;
uniform mediump samplerCube EnvironmentTexture;
uniform mediump sampler2D EmissiveTexture;
uniform mediump sampler2DShadow _Shadow;

// -------------------------------------
//Shlick Fresnel approximation
vec3 Fresnel(vec3 F0, vec3 h, vec3 v)
{
    float vDotH = clamp(dot(v, h), 0.0, 1.0);
    return F0 + (1.0f - F0) * pow(2.0, (-5.55473*vDotH - 6.98316)*vDotH);
    //return F0 + (1.0f - F0) * pow((1.0f - lDotH), 5.0f);
}

float GGX_Visibility(float K, float NdotX)
{
    return NdotX / (NdotX * (1.0 - K) + K);
}
vec3 GGX_Specular(float roughness, vec3 n, vec3 h, vec3 v, vec3 l, vec3 F0)
{
    float NdotL = clamp(dot(n, l), 0.0, 1.0);
    if (NdotL <= 0.0)
        return vec3(0.0);

    float NdotH = clamp(dot(n, h), 0.0, 1.0);
    float NdotV = clamp(dot(n, v), 0.0, 1.0);
    float NdotH2 = NdotH * NdotH;
    float alpha = roughness * roughness;
    float alpha2 = alpha * alpha;

    float d = alpha2 / (3.14159 * pow(NdotH2 * (alpha2 - 1.0) + 1.0, 2.0));

    float k = (roughness + 1.0)*(roughness + 1.0) / 8.0;
    float G = GGX_Visibility(k, NdotL)* GGX_Visibility(k, NdotV);

    vec3 f = Fresnel(F0, h, v);
	return clamp(d * f * G / (4.0 * NdotL*NdotV), vec3(0.0), vec3(1.0));
}


out vec4 fragColor;
// -------------------------------------
void main()
{		
	float roughness = gRoughness;
    float metal = gMetal;
    float ambient = gAmbient;
    float cavity = gCavity;

    if (gUseRMACTexture)
    {
        vec4 rmac = texture(RMACTexture, outUV0*rmacScale);
        roughness = rmac.x;
        metal = rmac.y;
        ambient = rmac.z;
        cavity = rmac.w;
    }
    

    if(gUseRoughnessTexture)
        roughness = texture(RoughnessTexture, outUV0*rmacScale).r;
    if(gUseMetalTexture)
        metal = texture(MetalTexture, outUV0*rmacScale).r;
    if(gUseAmbientTexture)
        ambient = texture(AmbientTexture, outUV0*rmacScale).r;
    if(gUseGlobalAO)
    {
        ambient *= texture(GlobalAOTexture, outUV1*globalAOScale).r;
    }
    if(gUseCavityTexture)
        cavity = texture(CavityTexture, outUV0*rmacScale).r;

    vec3 baseColor = gBaseColor.rgb;
    fragColor.a = gAlpha;
    if (gUseBaseTexture)
    {
		vec4 texRead = texture(BaseTexture, outUV0*btScale);
        baseColor = texRead.rgb;
		fragColor.a = texRead.a;
    }
    
    vec3 diffuseColor = (1.0 - metal)*baseColor.rgb;
    vec3 F0 = ((1.0 - metal)*0.04 + metal * baseColor.rgb);

    vec3 n = normalize(outNormal);
    if (gUseNormalTexture)
    {
        vec3 NORMALS = texture(NormalTexture, outUV0*btScale).rgb * 2.0 - 1.0;
        mat3 tangentToWorld = mat3(outTangent, outBinormal, outNormal);
        //n = normalize(mul(NORMALS, tangentToWorld));
        n = normalize(tangentToWorld * NORMALS);
	//float len = length(NORMALS);
        //float p = 2.0 / (roughness*roughness) + 2.0;
        //float alpha = 2.0 / (p*len / mix(p, 1.0, len) - 1.0);
        //roughness = sqrt(alpha);
    }

    const vec4 c0 = vec4 (-1.0, -0.0275, -0.572, 0.022);
    const vec4 c1 = vec4 (1.0, 0.0425, 1.04, -0.04);

    vec4 rr = roughness * c0 + c1;
	vec3 v = normalize(EyePosition.xyz - outWorldPosition);
    vec3 r = reflect(n,v);
    vec3 l = -normalize(LightDirection.xyz);
    vec3 h = normalize(l + v);
	float a004 = min(rr.x*rr.x, exp2(-9.28*dot(n,v))) * rr.x + rr.y;
	vec2 AB = vec2(-1.04, 1.04) * a004 + rr.zw;
	vec3 ambSpecColor = F0.rgb*AB.x+vec3(AB.y);
    vec3 ambientDiffuse = diffuseColor*AmbientColor.rgb;
    vec3 ambientSpecular = ambSpecColor*AmbientColor.rgb;
#define MAX_LOD 6.0
    if(gUseEnvironmentTexture)
    {    
        vec3 envDiff = textureLod(EnvironmentTexture,  n, MAX_LOD).rgb;
        float specularSampleLevel = roughness*MAX_LOD;//textureQueryLod(EnvironmentTexture, r).r*.8 * (1 - roughness) + MAX_LOD*roughness;
        vec3 envSpec = textureLod(EnvironmentTexture, r, specularSampleLevel).rgb;
        ambientDiffuse *= envDiff;
        ambientSpecular *= envSpec;
    }

	vec3 directDiffuse = clamp(dot(n,l), 0.0, 1.0)*diffuseColor/3.1415;
	vec3 directSpecular = GGX_Specular(roughness, n, h, v, l, F0);
	
    fragColor.rgb = //ComputeShadowAmount(input)*
                    LightColor.rgb*cavity*((clamp(dot(n, l), 0.0, 1.0)*diffuseColor + 
                    GGX_Specular(roughness, n, h, v, l, F0)));
    
    fragColor.rgb += ambient*(ambientDiffuse + ambientSpecular);
    
    if(gUseEmissiveTexture)
        fragColor.rgb += texture(EmissiveTexture, outUV0*btScale).rgb;
    else
        fragColor.rgb += gEmissive;
}

#endif //GLSL_FRAGMENT_SHADER
