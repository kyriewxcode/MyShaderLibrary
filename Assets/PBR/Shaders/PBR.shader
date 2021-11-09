Shader "Myshader/PBR Shader"
{
    Properties
    {
        _Color("Color",color) = (1,1,1,1)
        _GlossStrength("光滑强度",Range(0,1)) = 0.5
        _MainTex("漫反射贴图",2D) = "white"{}
        _MetallicGlossMap("金属图",2D) = "white"{} // R通道存储金属度，A通道存储光滑度
        _MetallicStrength("金属强度",Range(0,1)) = 1
        _BumpMap("法线贴图",2D) = "bump"{}
        _BumpScale("法线影响大小",float) = 1
        _OcclusionMap("环境光遮蔽纹理",2D) = "white"{}
        _EmissionColor("自发光颜色",color) = (0,0,0)
        _EmissionMap("自发光贴图",2D) = "white"{}
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
            Name "ForwardPass"
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            Cull back
            HLSLPROGRAM
            #pragma vertex vert;
            #pragma fragment frag;

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


            CBUFFER_START(UnityPerMaterial)

            half4 _Color;
            float _GlossStrength;

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            TEXTURE2D(_MetallicGlossMap);
            SAMPLER(sampler_MetallicGlossMap);
            float _MetallicStrength;

            TEXTURE2D(_BumpMap);
            SAMPLER(sampler_BumpMap);
            float _BumpScale;

            TEXTURE2D(_OcclusionMap);
            SAMPLER(sampler_OcclusionMap);

            TEXTURE2D(_EmissionMap);
            SAMPLER(sampler_EmissionMap);
            half4 _EmissionColor;

            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normal : NORMAL;
                float4 tangent :TANGENT;
                float2 texcoord : TEXCOORD0;
                float2 texcoord1 : TEXCOORD1;
                float2 texcoord2 : TEXCOORD2;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                half4 ambientOrLightmapUV : TEXCOORD1; //存储环境光或光照贴图的UV坐标
                float4 TtoW0 : TEXCOORD2;
                float4 TtoW1 : TEXCOORD3;
                float4 TtoW2 : TEXCOORD4; //xyz 存储着 从切线空间到世界空间的矩阵，w存储着世界坐标
            };

            // 计算环境光照或光照贴图uv坐标
            inline half4 VertexGI(float2 uv1, float2 uv2, float3 worldPos, float3 worldNormal)
            {
                half4 ambientOrLightmapUV = 0;


                return ambientOrLightmapUV;
            }

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertexInput.positionCS;
                output.uv = input.texcoord;

                half3 worldNormal = TransformObjectToWorldNormal(input.normal);
                output.ambientOrLightmapUV = VertexGI(input.texcoord1, input.texcoord2, vertexInput.positionWS, worldNormal);

                return output;
            }

            float4 frag(Varyings input) : SV_Target
            {
                float4 finalColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv) * _Color;

                
                return finalColor;
            }
            ENDHLSL
        }
    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}