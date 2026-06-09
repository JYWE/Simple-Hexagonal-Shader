Shader "Unlit/SimpleHexagonalShader"{
    Properties{
        _Density("Density",Range(0,200))=20//六边形密度
        _Offset("Offset",Vector)=(0,0,0,0)//偏移

        _BaseColor("BaseColor", Color)=(1,1,1,1)//灯的颜色
        _BloomColor("BloomColor", Color)=(0,0,1,1)//泛光的颜色
        _Width("Width",Range(0,0.5))=0.05//灯的宽度
        _AttenuationFactor("Attenuation Factor",Range(0,20))=4//泛光衰减速度
        _Clamp("Clamp",Range(0,1))=1//是否clamp，不clamp可能会叠加起来超过1
    }
    SubShader{
        Tags{
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
            "RenderType" = "Opaque" 
        }
        LOD 100
        Pass{
            Name "HelloWorld"
            ZWrite On
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            float _Density;
            float2 _Offset;

            float4 _BaseColor;
            float4 _BloomColor;
            float _Width;
            float _AttenuationFactor;
            float _Clamp;
            struct appdata{
                float4 positionOS:POSITION;
            };

            struct v2f{ 
                float2 positionOS:TEXCOORD0;
                float4 positionCS:SV_POSITION;
            };

            v2f vert(appdata v){
                v2f o;
                float3 tmp=TransformObjectToWorld(v.positionOS);
                o.positionOS=float2(v.positionOS.x,v.positionOS.y);
                o.positionCS=TransformWorldToHClip(tmp);
                return o;
            }

            //我们把显示屏的object space记作A
            //这个显示屏上面换用以(0,0)-(1,0)为底边的向上的正三角形的左、下两边为基向量建立直角坐标系形成的空间记作B
            //C表示坐标数值上与B相同的另外一个空间，基向量换成了(1,0)和(0,1)
            //pos是A中的这个点
            //A->B pos->v0
            //B->C v0->v0
            //C中这个点所在单位方格左下角->v1
            //构造了一个可以区分正六边形的六个三角形的东西，每个三角形有个编号->flag
            //v2->B或者C中正六边形中心
            //p1,p2->三角形的远离中心的边
            //f->C或者B到A的变换
            //最后A中求距离
            float2 f(float2 v){
                return float2(0.5*v.y+v.x,0.866025*v.y);//sqrt(3)/2==0.866025
            }
            float square(float x){
                return x*x;
            }
            float g(float x){//瞎取的
                return square(square(x));
            }
            float4 frag(v2f i):SV_Target{
                float2 pos=(i.positionOS+_Offset)*_Density;
                //
                float2 v0=float2(pos.x-pos.y*0.577350,pos.y*1.154701);//1/sqrt(3)==0.577350 2/sqrt(3)=1.154701
                int2 v1=int2(floor(v0));
                //
                int flag;
                int huge=12000000;//很大很大的6的倍数
                flag=((2*v1.x+(v0.x+v0.y>v1.x+v1.y+1)+v1.y*4)+huge)%6;
                
                // switch(flag){
                //     case 0:return float4(1,0,0,1);
                //     case 1:return float4(0,1,0,1);
                //     case 2:return float4(0,0,1,1);
                //     case 3:return float4(1,1,0,1);
                //     case 4:return float4(1,0,1,1);
                //     case 5:return float4(0,1,1,1);
                //     default:return float4(0,0,0,1);
                // }
                float2 v2;
                //之后改掉

                static const int2 offset[6]={
                    float2(0,0),
                    float2(1,1),
                    float2(0,1),
                    float2(0,1),
                    float2(1,0),
                    float2(1,0)
                };
                v2=v1+offset[flag];

                static const float2 p[6][2]={
                    {float2(0,1),float2(1,0)},
                    {float2(0,-1),float2(-1,0)},
                    {float2(0,-1),float2(1,-1)},
                    {float2(1,-1),float2(1,0)},
                    {float2(-1,0),float2(-1,1)},
                    {float2(0,1),float2(-1,1)}
                };
                float2 p1=v2+p[flag][0];
                float2 p2=v2+p[flag][1];
                //A中求距离
                float dis=dot(normalize(f((p1+p2)/2-v2)),pos-f(v2));

                
                //上色
                float edge=0.866025-_Width;//此处是那个灯光的内边缘
                float baseStrength=(dis>=edge);
                float bloomStrength=clamp(1.0/g(1+clamp(edge-dis,0,1)*_AttenuationFactor),0,1);
                float4 col=_BloomColor*bloomStrength+_BaseColor*baseStrength;
                if(_Clamp>=0.5){col.r=clamp(col.r,0,1);col.g=clamp(col.g,0,1);col.b=clamp(col.b,0,1);}
                col.a=1;
                return col;
            }
            ENDHLSL
        }
    }
}
