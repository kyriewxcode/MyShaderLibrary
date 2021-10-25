Shader "Hidden/PostProcess/Fog"
{
    Properties
    {
        [HideInInspector]_MainTex("Base (RGB)", 2D) = "white" {}
        _FogDensity ("Fog Density", Float) = 1.0
        _FogColor ("Fog Color", Color) = (1, 1, 1, 1)
        _FogStart ("Fog Start", Float) = 0.0
        _FogEnd ("Fog End", Float) = 1.0
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "IgnoreProjector" = "True"
            "RenderPipeline" = "UniversalPipeline"
        }
        LOD 100

        Pass
        {
            Name "DepthMap"
            HLSLPROGRAM
            #pragma vertex vert;
            #pragma fragment frag;

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Assets/URP/RenderFeature/RenderFeatureTools.hlsl"

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            TEXTURE2D(_CameraDepthNormalsTexture);
            SAMPLER(sampler_CameraDepthNormalsTexture);

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            half _FogDensity;
            half4 _FogColor;
            float _FogStart;
            float _FogEnd;
            float4x4 _FrustumCornersRay;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 texcoord : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                half2 uv_depth : TEXCOORD1;
                float4 interpolatedRay : TEXCOORD2;
            };

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertexInput.positionCS;
                output.uv = input.texcoord;
                output.uv_depth = input.texcoord;

                int index = 0;
                if (input.texcoord.x < 0.5 && input.texcoord.y < 0.5)
                {
                    index = 0;
                }
                else if (input.texcoord.x > 0.5 && input.texcoord.y < 0.5)
                {
                    index = 1;
                }
                else if (input.texcoord.x > 0.5 && input.texcoord.y > 0.5)
                {
                    index = 2;
                }
                else
                {
                    index = 3;
                }

                output.interpolatedRay = _FrustumCornersRay[index];

                return output;
            }

            float4 frag(Varyings input) : SV_Target
            {
                float linearDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, input.uv_depth);

                linearDepth = LinearEyeDepth(linearDepth, _ZBufferParams);
                float3 worldPos = _WorldSpaceCameraPos + linearDepth * input.interpolatedRay.xyz;

                float fogDensity = (_FogEnd - worldPos.y) / (_FogEnd - _FogStart);
                fogDensity = saturate(fogDensity * _FogDensity);

                float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                color.rgb = lerp(color.rgb, _FogColor.rgb, fogDensity);
                return color;
            }
            ENDHLSL
        }
    }
}