Shader "MeshCloud"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_CloudOcclLobePower("CloudOcclLobePower", Float) = 5
		_CloudExtinct("Extinct", Float) = 0.2
		_CloudTransmissionBias("TransmissionBias", Float) = 0.1
    }
    SubShader
    {
        LOD 100

        Pass
        {
			Tags { "RenderType" = "Opaque" "LightMode" = "ForwardBase" }

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
			#include "Lighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
				float2 uv2 : TEXCOORD1;
				float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
				float3 info : TEXCOORD2;//x transmit light, y transmit sky, z depth
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
			float _CloudOcclLobePower;
			float _CloudTransmissionBias;
			float _CloudExtinct;


            v2f vert (appdata v)
            {
                v2f o;
				float3 viewNormal = normalize(mul((float3x3)UNITY_MATRIX_IT_MV, v.normal));
				float3 worldNormal = UnityObjectToWorldNormal(v.normal);
				float3 viewPos = UnityObjectToViewPos(v.vertex);
				float linearDepth = saturate(-viewPos.z * _ProjectionParams.w);
                o.vertex = mul(UNITY_MATRIX_P,float4( viewPos,1));
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
				float3 occDir = float3(v.uv.x, -v.uv.y, -v.uv2.x);
				float3 occDistPt = float3(v.uv2.y, 0, 0);
				float3 worldSpaceOccDir = UnityObjectToWorldDir(occDir);
				float3 worldSpaceOccDist = mul(unity_ObjectToWorld, occDistPt);
				float occDist = length(worldSpaceOccDist);
				float3 lightDir = -normalize(_WorldSpaceLightPos0.xyz);
				float LdOc = dot(lightDir, normalize(worldSpaceOccDir));
				float transmittanceDistLight = pow(LdOc / 2 + 0.5, _CloudOcclLobePower)*occDist + _CloudTransmissionBias;
				float transmitLight = exp(-transmittanceDistLight * _CloudExtinct);
				float LdN = saturate(dot(lightDir, worldNormal));
				float halfLambertLight = lerp(0.8f, 1.0f, LdN);
				transmitLight *= halfLambertLight;

				float SldOc = dot(float3(0,-1,0), normalize(worldSpaceOccDir));
				float transmittanceDistSky = pow(SldOc / 2 + 0.5, _CloudOcclLobePower)*occDist + _CloudTransmissionBias;
				float transmitSky = exp(-transmittanceDistSky * _CloudExtinct);
				float SldN = saturate(dot(float3(0, -1, 0), worldNormal));
				float halfLambertSky = lerp(0.8f, 1.0f, SldN);
				transmitSky *= halfLambertSky;

				o.info = float3(transmitLight, transmitSky, linearDepth);
                return o;
            }

			float4 frag (v2f i) : SV_Target
            {
				return float4(i.info.x, i.info.y, 1, i.info.z);
            }
            ENDCG
        }
    }

	Fallback "Standard"
}
