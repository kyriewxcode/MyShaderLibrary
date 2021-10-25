Shader "Hidden/PostProcess/DepthMap"
{
    Properties {}
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

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 texcoord : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertexInput.positionCS;
                output.uv = input.texcoord;

                return output;
            }

            float4 frag(Varyings input) : SV_Target
            {
                float depth = SAMPLE_DEPTH_TEXTURE(
                    _CameraDepthTexture,
                    sampler_CameraDepthTexture,
                    UnityStereoTransformScreenSpaceTex(input.uv));

                depth = Linear01Depth(depth, _ZBufferParams);

                return float4(depth, depth, depth, 1);
            }
            ENDHLSL
        }
    }
}