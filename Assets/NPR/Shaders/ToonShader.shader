Shader "Myshader/ToonShader"
{
	Properties
	{
		[Header(Toon Shading)]
		_LightTexture("亮部贴图", 2D) = "white" {}
		_LightColor("亮部颜色", Color) = (1,1,1,1)
		_ShadowTexture("暗部贴图", 2D) = "white" {}
		_ShadowColor("暗部颜色", Color) = (1,1,1,1)
		_CelMidPoint ("明暗交界点", Range(0,1)) = 0.5
		_CelSoftness ("明暗柔和度", Range(0.001,1)) = 0.1

		[Header(Lighting)]
		[Toggle(ENABLE_NORMAL_MAP)] _EnableNormalMap("使用法线贴图", Float) = 0.0
		_NormalMap("法线贴图", 2D) = "white" {}
		[Toggle(ENABLE_RIM_LIGHT)] _EnableRimLight("使用轮廓光", Float) = 0.0
		_RimColor("Rim Color", Color) = (1,1,1,1)
		_RimMin("Rim Mix", Range(0,2)) = 0.5
		_RimMax("Rim Max", Range(0,2)) = 1.0
		[Toggle(ENABLE_FRESNEL)] _EnableFresnel("使用菲涅尔效应", Float) = 0.0
		_FresnelStrength("菲涅尔强度", Range(0,1)) = 0.0

		[Header(Outline)]
		_Outline_sampler ("Outline_sampler", 2D) = "white" {}
		_Outline_Width ("Outline_Width", Range(0, 10)) = 0
		_Line_Color ("Line_Color", Color) = (0.5,0.5,0.5,1)
		[Toggle(WS_OUTLINE)] _EnableWSOutline("在世界空间法线外扩", Float) = 1.0

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

			#pragma shader_feature_local ENABLE_NORMAL_MAP
			#pragma shader_feature_local ENABLE_RIM_LIGHT
			#pragma shader_feature_local ENABLE_FRESNEL

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

			TEXTURE2D(_LightTexture);
			SAMPLER(sampler_LightTexture);

			TEXTURE2D(_ShadowTexture);
			SAMPLER(sampler_ShadowTexture);

			TEXTURE2D(_NormalMap);
			SAMPLER(sampler_NormalMap);

			CBUFFER_START(UnityPerMaterial)
			half4 _LightColor;
			half4 _ShadowColor;
			half _CelMidPoint;
			half _CelSoftness;
			half4 _RimColor;
			half _RimMin;
			half _RimMax;
			half _FresnelStrength;
			CBUFFER_END

			struct Attributes
			{
				float4 positionOS : POSITION;
				half4 tangentOS : TANGENT;
				half3 normalOS : NORMAL;
				half2 uv : TEXCOORD0;
			};

			struct Varyings
			{
				float4 positionCS : SV_POSITION;
				half3 positionWS : TEXCOORD0;
				half2 uv : TEXCOORD1;
				float3 normalWS : TEXCOORD2;

				#if defined(ENABLE_NORMAL_MAP)
				half4 tangentWS : TEXCOORD3;
				#endif
			};

			Varyings vert(Attributes input)
			{
				Varyings output = (Varyings)0;
				VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
				output.positionCS = vertexInput.positionCS;
				output.positionWS = vertexInput.positionWS;

				output.uv = input.uv;
				output.normalWS = TransformObjectToWorldNormal(input.normalOS);

				#if defined(ENABLE_NORMAL_MAP)
				half sign = input.tangentOS.w * GetOddNegativeScale(); // 判断法线贴图是否需要取反
				half3 tangentWS = TransformObjectToWorldDir(input.tangentOS);
				output.tangentWS = half4(tangentWS, sign);
				#endif

				return output;
			}


			half4 frag(Varyings input) : SV_Target
			{
				half3 finalColor = 0;


				// 计算法线
				#if defined(ENABLE_NORMAL_MAP)
				half4 normalMap = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv);
				half3 normalTS = UnpackNormal(normalMap);
				half sign = input.tangentWS.w;
				half3 bitangent = sign * cross(normalize(input.normalWS), normalize(input.tangentWS.xyz));
				input.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS));
				#endif

				// 亮部暗部插值
				Light mainLight = GetMainLight();
				float3 lightDirWS = mainLight.direction - input.positionWS;
				half3 lightColor = SAMPLE_TEXTURE2D(_LightTexture, sampler_LightTexture, input.uv).rgb
					* _LightColor.rgb;
				half3 shadowColor = SAMPLE_TEXTURE2D(_ShadowTexture, sampler_ShadowTexture, input.uv).rgb
					* _ShadowColor.rgb;
				half NdotL = saturate(dot(input.normalWS, lightDirWS));
				half litOrShadowArea = smoothstep(_CelMidPoint - _CelSoftness, _CelMidPoint + _CelSoftness, NdotL);
				finalColor = lerp(shadowColor, lightColor, litOrShadowArea);
				finalColor *= mainLight.color;

				float3 viewDirWS = SafeNormalize(GetCameraPositionWS() - input.positionWS);
				// 菲涅尔效应
				#if defined(ENABLE_FRESNEL)
				half3 R0 = half3(0.04, 0.04, 0.04);
				float cosTheta = max(dot(viewDirWS, input.normalWS), 0);
				half3 fresnelResult = R0 + (1.0 - R0) * pow(max(1.0 - cosTheta, 0), 5.0);
				fresnelResult = fresnelResult * _FresnelStrength * (1 - dot(viewDirWS, mainLight.direction)) * 0.5;
				finalColor += fresnelResult;
				#endif

				// 轮廓光
				#if defined(ENABLE_RIM_LIGHT)
				half NdotV = max(dot(input.normalWS, viewDirWS), 0);
				half3 rim = 1 - NdotV;
				rim = smoothstep(_RimMin, _RimMax, rim) * _RimColor;
				finalColor += rim;
				#endif

				return half4(finalColor, 1);
			}
			ENDHLSL
		}
		Pass
		{
			Name "Outline"
			Tags
			{
				"LightMode" = "SRPDefaultUnlit"
			}
			Cull Front
			HLSLPROGRAM
			#pragma vertex vert;
			#pragma fragment frag;

			#pragma shader_feature_local WS_OUTLINE

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			TEXTURE2D(_MainTex);
			SAMPLER(sampler_MainTex);
			float4 _MainTex_ST;

			TEXTURE2D(_Outline_sampler);
			SAMPLER(sampler_Outline_sampler);

			uniform float _Outline_Width;
			uniform float4 _Line_Color;

			struct Attributes
			{
				float4 positionOS : POSITION;
				half3 normalOS : NORMAL;
				half2 uv : TEXCOORD0;
			};

			struct Varyings
			{
				float4 positionCS : SV_POSITION;
				half2 uv : TEXCOORD0;
			};

			Varyings vert(Attributes input)
			{
				Varyings output = (Varyings)0;
				output.uv = input.uv;
				float4 outline = SAMPLE_TEXTURE2D_LOD(_Outline_sampler, sampler_Outline_sampler, 0.0, 0);
				#if defined(WS_OUTLINE)
				output.positionCS = TransformObjectToHClip(
					input.positionOS.xyz + input.normalOS * (outline.rgb * _Outline_Width * 0.001).r);
				#else
				output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
				float3 norm = mul((float3x3)UNITY_MATRIX_IT_MV, input.normalOS);
				float2 extendDir = mul((float2x2)UNITY_MATRIX_P, norm.xy);
				output.positionCS.xy += extendDir * (outline.rgb * _Outline_Width * 0.001 * output.positionCS.w).xy;
				#endif
				return output;
			}

			float4 frag(Varyings input) : SV_Target
			{
				float4 _MainTex_var = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, TRANSFORM_TEX(input.uv, _MainTex));
				return float4(((_MainTex_var.rgb * _MainTex_var.rgb) * _Line_Color.rgb), 0);
			}
			ENDHLSL
		}
	}
	FallBack "Hidden/Universal Render Pipeline/FallbackError"
}