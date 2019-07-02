Shader "Hidden/CloudPostProcessing"
{
    Properties
    {
		_WrapTex("WrapTex", 2D) = "white" {}
	_SwirlStrength("SwirlStrength", Float) = 0.005
		_SwirlSpeed("SwirlSpeed", Float) = 1.0
		_WrapTile("WrapTile", Float) = 2.0
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass 
        {
			Name "BoxBlurDepth"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
				float4 uv_offset1 : TEXCOORD1;
				float4 uv_offset2 : TEXCOORD2;
				float4 uv_offset3 : TEXCOORD3;
				float4 uv_offset4 : TEXCOORD4;
            };

			sampler2D _MainTex;
			sampler2D _CloudTarget;
			float4 _CloudTarget_TexelSize;
			sampler2D _Wrap;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
				o.uv_offset1 = float4(_CloudTarget_TexelSize.x, 0, -_CloudTarget_TexelSize.x, 0);
				o.uv_offset2 = float4(0, _CloudTarget_TexelSize.y, 0, -_CloudTarget_TexelSize.y);
				o.uv_offset3 = float4(_CloudTarget_TexelSize.x, _CloudTarget_TexelSize.y, -_CloudTarget_TexelSize.x, -_CloudTarget_TexelSize.y);
				o.uv_offset4 = float4(_CloudTarget_TexelSize.x,- _CloudTarget_TexelSize.y, -_CloudTarget_TexelSize.x, _CloudTarget_TexelSize.y);

                return o;
            }

			float4 frag (v2f i) : SV_Target
            {
				float4 cloud0 = tex2D(_CloudTarget, i.uv);
				float blur_range = saturate(cloud0.w) * 3.0f;
				blur_range = 2.0f;

				float4 cloud_blur = cloud0;
				float4 cloud_offset = 0;
				float shrink = cloud0.z;
				cloud_offset = tex2D(_CloudTarget, i.uv + i.uv_offset1.xy * blur_range);
				cloud_blur += cloud_offset;
				shrink = min(shrink, cloud_offset.z);
				cloud_offset  = tex2D(_CloudTarget, i.uv + i.uv_offset1.zw * blur_range);
				cloud_blur += cloud_offset;
				shrink = min(shrink, cloud_offset.z);
				cloud_offset = tex2D(_CloudTarget, i.uv + i.uv_offset2.xy * blur_range);
				cloud_blur += cloud_offset;
				shrink = min(shrink, cloud_offset.z);
				cloud_offset = tex2D(_CloudTarget, i.uv + i.uv_offset2.zw * blur_range);
				cloud_blur += cloud_offset;
				shrink = min(shrink, cloud_offset.z);
				cloud_offset = tex2D(_CloudTarget, i.uv + i.uv_offset3.xy * blur_range);
				cloud_blur += cloud_offset;
				shrink = min(shrink, cloud_offset.z);
				cloud_offset = tex2D(_CloudTarget, i.uv + i.uv_offset3.zw * blur_range);
				cloud_blur += cloud_offset;
				shrink = min(shrink, cloud_offset.z);
				cloud_offset = tex2D(_CloudTarget, i.uv + i.uv_offset4.xy * blur_range);
				cloud_blur += cloud_offset;
				shrink = min(shrink, cloud_offset.z);
				cloud_offset = tex2D(_CloudTarget, i.uv + i.uv_offset4.zw * blur_range);
				cloud_blur += cloud_offset;
				shrink = min(shrink, cloud_offset.z);

				cloud_blur /= 9.0f;

				return float4(cloud0.xy, saturate(shrink), cloud_blur.w);
            }
            ENDCG
        }

		 Pass
		{
			Name "CompositeCloud"
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			#include "Lighting.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			sampler2D _MainTex;
			sampler2D _CloudBlured;
			sampler2D _Background;

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}

			float4 frag(v2f i) : SV_Target
			{
				float4 cloud = tex2D(_CloudBlured, i.uv);
				float4 color = lerp(unity_AmbientGround, _LightColor0, cloud.x) + lerp(unity_AmbientGround, unity_AmbientSky, cloud.y);
				float4 main = tex2D(_Background, i.uv);

				float viewZ = cloud.w / _ProjectionParams.w;
				float fogParam = saturate(unity_FogParams.w + viewZ * unity_FogParams.z);
				color = lerp(unity_FogColor, color, fogParam);

				return lerp(main, color, cloud.b);
				
			}
			ENDCG
		}

		Pass
		{
			Name "GaussianBlur"
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			#include "Lighting.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float4 uv01 : TEXCOORD1;
				float4 uv23 : TEXCOORD2;
				float4 uv45 : TEXCOORD3;
			};

			sampler2D _SourceTex;

			float4 offsets;

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				o.uv01 = v.uv.xyxy + offsets.xyxy * float4(1, 1, -1, -1);
				o.uv23 = v.uv.xyxy + offsets.xyxy * float4(1, 1, -1, -1) * 2.0;
				o.uv45 = v.uv.xyxy + offsets.xyxy * float4(1, 1, -1, -1) * 3.0;
				return o;
			}

			half4 frag(v2f i) : SV_Target
			{
				half4 color = tex2D(_SourceTex, i.uv);
				float deviation = max(lerp(10.0f,-5.0f, color.w), 0.01f);
				float minusHalfDeviSqr = rcp(-0.5f * deviation * deviation);

				float factor1 = exp(minusHalfDeviSqr * 1);
				float factor2 = exp(minusHalfDeviSqr * 4);
				float factor3 = exp(minusHalfDeviSqr * 9);
				float factorAll = (((1.0f + 2.0f * factor1) + 2.0f * factor2) + 2.0f * factor3);

				color += factor1 * tex2D(_SourceTex, i.uv01.xy);
				color += factor1 * tex2D(_SourceTex, i.uv01.zw);
				color += factor2 * tex2D(_SourceTex, i.uv23.xy);
				color += factor2 * tex2D(_SourceTex, i.uv23.zw);
				color += factor3 * tex2D(_SourceTex, i.uv45.xy);
				color += factor3 * tex2D(_SourceTex, i.uv45.zw);

				color *= rcp(factorAll);

				return float4(color.xy, saturate(color.z), color.w);
			}
			ENDCG
		}

		Pass
		{
			Name "ApplyCloudNoise"
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			#include "Lighting.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			sampler2D _SourceTex;
			sampler2D _WrapTex;
			float4 _WrapTex_ST;

			float _SwirlSpeed;
			float _SwirlStrength;
			float4 offsets;
			float _WrapTile;

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}

			float3 FlowUVW(float2 uv, float2 flowVector, float time, bool flowB) {
				float phaseOffset = flowB ? 0.5 : 0;
				float progress = frac(time + phaseOffset);
				float3 uvw;
				uvw.xy = uv - flowVector * progress;
				uvw.z = 1 - abs(1 - 2 * progress);
				return uvw;
			}

			half4 frag(v2f i) : SV_Target
			{
				half4 color = tex2D(_SourceTex, i.uv);
				half3 wrapNear = tex2D(_WrapTex, i.uv * _WrapTile * 1.0f + float2(_Time.y*_SwirlSpeed, 0));
				half3 wrapFar = tex2D(_WrapTex, i.uv * _WrapTile * 4.0f + float2(_Time.y*_SwirlSpeed, 0) * 0.5f);
				half3 wrap = lerp(wrapFar, wrapNear, saturate(1-color.w));
				float wrapStrength = lerp(_SwirlStrength /10, _SwirlStrength, saturate(1-color.w));

				wrap = wrap * 2.0f - 1.0f;
				wrap *= wrapStrength;
				float3 uvwA = FlowUVW(i.uv, wrap.xy, _Time.x*_SwirlSpeed *10, 0);
				float3 uvwB = FlowUVW(i.uv, wrap.xy, _Time.x*_SwirlSpeed *10, 1);

				float dark = lerp(0.8f, 1.0f, wrapNear.x * wrapFar.x);

				half4 texA = tex2D(_SourceTex, uvwA.xy) * uvwA.z;
				half4 texB = tex2D(_SourceTex, uvwB.xy) * uvwB.z;

				half4 flowSum = texA + texB;
				//return float4(wrap, 1);
				//float dep = saturate(color.w);
				//return float4(dep, dep, texA.z+texB.z, 1);
				return float4(dark*flowSum.xy, flowSum.zw);
			}
			ENDCG
		}
    }
}
