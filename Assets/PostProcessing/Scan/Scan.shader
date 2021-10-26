Shader "Hidden/PostProcess/Scan"
{
    Properties
    {
        [HideInInspector]_MainTex("Base (RGB)", 2D) = "white" {}
        _ScanColor ("Scan Color", Color) = (1, 1, 1, 1)
        _ScanDistance ("Scan Distance", Float) = 0.0
        _ScanRange ("Scan Range", Float) = 1.0
        _ScanTex ("Scan Texture",2D) = "white"
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

            TEXTURE2D(_ScanTex);
            SAMPLER(sampler_ScanTex);
            float _MeshWidth;

            float4x4 _FrustumCornersRay;
            float4x4 _CamToWorld;
            vector _ScanCenter;

            float _ScanDistance;
            float _ScanRange;

            float4 _ScanColor;

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

                float depth = LinearEyeDepth(
                    SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, input.uv_depth), _ZBufferParams);

                half3 normal = DecodeDepthNormal(SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, input.uv_depth)).
                    xyz;;
                normal = mul((float3x3)_CamToWorld, normal);
                normal = normalize(abs(normal));

                float3 worldPos = _WorldSpaceCameraPos + depth * input.interpolatedRay.xyz;
                float distanceFromCenter = distance(worldPos, _ScanCenter.xyz);

                float3 modulo = worldPos - _MeshWidth * floor(distanceFromCenter / _MeshWidth);
                modulo = modulo / _MeshWidth;

                half4 c_right = SAMPLE_TEXTURE2D(_ScanTex, sampler_ScanTex, modulo.yz) * normal.x;
                half4 c_front = SAMPLE_TEXTURE2D(_ScanTex, sampler_ScanTex, modulo.xy) * normal.z;
                half4 c_up = SAMPLE_TEXTURE2D(_ScanTex, sampler_ScanTex, modulo.xz) * normal.y;
                half4 scanMeshCol = saturate(c_up + c_right + c_front);

                if (_ScanDistance - distanceFromCenter > 0
                    && _ScanDistance - distanceFromCenter < _ScanRange
                    && depth < _ProjectionParams.z)
                {
                    float diff = 1 - (_ScanDistance - distanceFromCenter) / _ScanRange;
                    finalColor = lerp(finalColor, scanMeshCol * _ScanColor, saturate(diff));
                }

                return finalColor;
            }
            ENDHLSL
        }
    }
}