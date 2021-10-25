Shader "Hidden/PostProcess/EdgeDetectionOutline"
{
    Properties
    {
        _MainTex ("Base (RGB)", 2D) = "white" {}
        _EdgeOnly ("Edge Only", Float) = 1.0
        _EdgeColor ("Edge Color", Color) = (0, 0, 0, 1)
        _BackgroundColor ("Background Color", Color) = (1, 1, 1, 1)
        _SampleDistance ("Sample Distance", Float) = 1.0
        _Sensitivity ("Sensitivity", Vector) = (1, 1, 1, 1)
    }
    SubShader
    {
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Assets/URP/RenderFeature/RenderFeatureTools.hlsl"

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            float4 _MainTex_TexelSize;

            TEXTURE2D(_CameraDepthNormalsTexture);
            SAMPLER(sampler_CameraDepthNormalsTexture);

            half _EdgeOnly;
            half4 _EdgeColor;
            half4 _BackgroundColor;
            float _SampleDistance;
            half4 _Sensitivity;

            struct Attributes
            {
                float4 positionOS : POSITION;
                half2 texcoord : TEXCOORD0;
            };

            struct Varyings
            {
                float4 vertex : SV_POSITION;
                half2 uv[5] : TEXCOORD0;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.vertex = vertexInput.positionCS;

                half2 uv = input.texcoord;
                output.uv[0] = uv;

                #if UNITY_UV_STARTS_AT_TOP
                if (_MainTex_TexelSize.y < 0)
                    uv.y = 1 - uv.y;
                #endif

                output.uv[1] = uv + _MainTex_TexelSize.xy * half2(1, 1) * _SampleDistance;
                output.uv[2] = uv + _MainTex_TexelSize.xy * half2(-1, -1) * _SampleDistance;
                output.uv[3] = uv + _MainTex_TexelSize.xy * half2(-1, 1) * _SampleDistance;
                output.uv[4] = uv + _MainTex_TexelSize.xy * half2(1, -1) * _SampleDistance;

                return output;
            }

            half CheckSame(half4 center, half4 sample)
            {
                half2 centerNormal = center.xy;
                float centerDepth = DecodeFloatRG(center.zw);
                half2 sampleNormal = sample.xy;
                float sampleDepth = DecodeFloatRG(sample.zw);

                half2 diffNormal = abs(centerNormal - sampleNormal) * _Sensitivity.x;
                int isSameNormal = (diffNormal.x + diffNormal.y) < 0.1;

                float diffDepth = abs(centerDepth - sampleDepth) * _Sensitivity.y;
                int isSameDepth = diffDepth < 0.1 * centerDepth;

                return isSameNormal * isSameDepth ? 1.0 : 0.0;
            }

            float4 frag(Varyings input) : SV_Target
            {
                half4 sample1 = SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, input.uv[1]);
                half4 sample2 = SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, input.uv[2]);
                half4 sample3 = SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, input.uv[3]);
                half4 sample4 = SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, input.uv[4]);

                half edge = 1.0;

                edge *= CheckSame(sample1, sample2);
                edge *= CheckSame(sample3, sample4);
                half4 withEdgeColor = lerp(_EdgeColor, SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv[0]), edge);
                half4 onlyEdgeColor = lerp(_EdgeColor, _BackgroundColor, edge);
                return lerp(withEdgeColor, onlyEdgeColor, _EdgeOnly);
            }
            ENDHLSL
        }
    }
    FallBack "Diffuse"
}