Shader "Lumi/StandardPBR"
{
    Properties
    {
        
        _BaseTex("Base", 2D) = "white" {}
        _TintColor("Base", Color) = (1,1,1,1)
        _MixMap("Mix", 2D) = "white" {}
        _Metallic("Metallic", Range(0, 1)) = 0.5
        _Smoothness("Smoothness", Range(0, 1)) = 0.0

    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
            
            #include "UnityCG.cginc"
            #include "UnityPBSLighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal: NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float3 normal: TEXCOORD1;
                float3 worldPos: TEXCOORD2;
            };

            float4 _TintColor;
            float _Metallic;
            float _Smoothness;
            sampler2D _BaseTex;
            float4 _BaseTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _BaseTex);
                o.normal = normalize(UnityObjectToWorldNormal(v.normal));
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                i.normal = normalize(i.normal);

                float3 albedo = tex2D(_BaseTex, i.uv).rgb * _TintColor.rgb;
                float3 specularFactor;
                float glossiness;
                albedo = DiffuseAndSpecularFromMetallic(albedo, _Metallic, specularFactor, glossiness);

                // World Directional Light
                float3 lightDir = _WorldSpaceLightPos0.xyz;
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                float3 lightColor = _LightColor0.rgb;

                UnityLight light;
                light.color = lightColor;
                light.dir = lightDir;
                light.ndotl = DotClamped(i.normal, lightDir);

                UnityIndirect indirectLight;
                indirectLight.diffuse = 0;
                indirectLight.specular = 0;

                return UNITY_BRDF_PBS(
                    albedo, specularFactor,
                    glossiness, _Smoothness,
                    i.normal, viewDir,
                    light, indirectLight
                );
            }
            ENDCG
        }
    }
}
