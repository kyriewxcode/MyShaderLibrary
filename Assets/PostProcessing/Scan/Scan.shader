Shader "Hidden/PostProcess/Scan"
{
    Properties
    {
        [HideInInspector]_MainTex("Base (RGB)", 2D) = "white" {}
        _ScanDistance ("ScanDistance", Float) = 0.0
        _ScanRange ("ScanRange", Float) = 1.0
        _ScanColor ("ScanColor", Color) = (1,1,1,1)
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

            float4x4 _FrustumCornersRay;
            vector _ScanCenter;

            float _ScanDistance;
            float _ScanRange;
            half4 _ScanColor;

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

                //当前顶点是四边形的哪个顶点：0-bl, 1-br, 2-tr, 3-tl
                int index = 0;
                if (input.texcoord.x < 0.5 && input.texcoord.y < 0.5)
                    index = 0;
                else if (input.texcoord.x > 0.5 && input.texcoord.y < 0.5)
                    index = 1;
                else if (input.texcoord.x > 0.5 && input.texcoord.y > 0.5)
                    index = 2;
                else
                    index = 3;

                output.interpolatedRay = _FrustumCornersRay[index];

                return output;
            }

            float4 frag(Varyings input) : SV_Target
            {
                half4 finalColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);

                float linearDepth = LinearEyeDepth(
                    SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, input.uv_depth), _ZBufferParams);

                float3 worldPos = _WorldSpaceCameraPos + linearDepth * input.interpolatedRay.xyz;

                float distanceFromCenter = distance(worldPos, _ScanCenter);

                if (distanceFromCenter < _ScanDistance && linearDepth < _ProjectionParams.z)
                {
                    float diff = 1 - (_ScanDistance - distanceFromCenter) / _ScanRange;
                    finalColor = lerp(finalColor, _ScanColor, saturate(diff));
                }

                return finalColor;
            }
            ENDHLSL
        }
    }
}