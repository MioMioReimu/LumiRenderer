Shader "Lumi/MyStandardPBR"
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
        Tags { "RenderType" = "Opaque" }
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

            struct brdf_data {
                float3 albedo;
                float3 frenel0;
                float glossiness;
                float roughness;
                float nv;
                float nl;
                float vh;
                float nh;
                float lh;
            };

            struct brdf_light {
                float3 color;
                float3 dir;
                float nl;
            };

            inline float3 LambertDiffuse(UnityLight light, float3 albedo) {
                return albedo * light.color * light.ndotl;
            }

            inline float D_TrowbridgeReitzGGX(float roughness, float nh) {
                float alpha_2 = pow(lerp(0.002, 1.0, roughness), 2);
                float deno = pow(nh, 2) * (alpha_2 - 1) + 1;
                return alpha_2 / (UNITY_PI * pow(deno, 2));
            }

            inline float GSubSchlickGGX(float nv, float k) {
                return nv / lerp(nv, 1.0, k);
            }

            inline float GSchlickGGX(float nv, float nl, float k) {
                return GSubSchlickGGX(nv, k) * GSubSchlickGGX(nl, k);
            }

            inline float3 FSchlick(float cosTheta, float3 F0) {
                float t = 1.0 - cosTheta;
                float t_2 = t * t;
                return F0 + (1.0 - F0) * t_2 * t_2 * t;
            }

            inline float3 BRDFCookTorrance(brdf_light light, brdf_data brdf) {
                float D = D_TrowbridgeReitzGGX(brdf.roughness, brdf.nh);
                float squareRoughness = brdf.roughness * brdf.roughness;
                float k = pow(squareRoughness + 1, 2) / 8;
                float G = GSchlickGGX(brdf.nv, brdf.nl, k);
                float3 F = FSchlick(brdf.vh, brdf.frenel0);
                float3 specular = (D * G * F * 0.25) / (brdf.nv * brdf.nl);

                float3 kd = (1 - F) * sqrt(brdf.roughness);

                //直接光照部分结果
                float3 specColor = specular * light.color * brdf.nl * UNITY_PI;
                float3 diffColor = kd * brdf.albedo * light.color * brdf.nl;
                return specColor + diffColor;
            }
            
            inline void InitBRDF(float3 normal, float3 lightDir, float3 viewDir, inout brdf_data brdf) {
                float3 halfvl = normalize(lightDir + viewDir);

                brdf.nl = max(saturate(dot(normal, lightDir)), 0.00001);
                brdf.nv = max(saturate(dot(normal, viewDir)), 0.00001);
                brdf.vh = max(saturate(dot(viewDir, halfvl)), 0.00001);
                brdf.lh = max(saturate(dot(lightDir, halfvl)), 0.00001);
                brdf.nh = max(saturate(dot(normal, halfvl)), 0.00001);
            }

            inline void ConvertFromMetallicStyle(float3 albedo, float metallic, inout brdf_data brdf) {
                float3 f0 = lerp(unity_ColorSpaceDielectricSpec.rgb, albedo, metallic);

                brdf.frenel0 = f0;
                brdf.glossiness = (1.0 - metallic) * unity_ColorSpaceDielectricSpec.a;
                brdf.albedo = brdf.glossiness * albedo;
                brdf.roughness = 1 - _Smoothness;
                brdf.roughness *= brdf.roughness;
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _BaseTex);
                o.normal = normalize(UnityObjectToWorldNormal(v.normal));
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                i.normal = normalize(i.normal);

                float3 albedo = tex2D(_BaseTex, i.uv).rgb * _TintColor.rgb;
                brdf_data brdf = (brdf_data)0;

                ConvertFromMetallicStyle(albedo, _Metallic, brdf);

                // World Directional Light
                float3 lightDir = _WorldSpaceLightPos0.xyz;
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                InitBRDF(i.normal, lightDir, viewDir, brdf);
                
                brdf_light light;
                light.color = _LightColor0.rgb;
                light.dir = lightDir;
                light.nl = brdf.nl;

                float4 out_color = { 0.0, 0.0, 0.0, 0.0 };
                out_color.xyz = BRDFCookTorrance(light, brdf);

                return out_color;
            }
            ENDCG
        }
    }
}
