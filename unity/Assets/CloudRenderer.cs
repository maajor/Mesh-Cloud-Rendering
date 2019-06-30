using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering;
using Random = UnityEngine.Random;

[ExecuteInEditMode]
public class CloudRenderer : MonoBehaviour
{
    public Shader CloudShader;
    public Shader CloudPostProcessingShader;
    public Texture2D CloudNoiseTex;
    public List<GameObject> CloudTemplates;

    public float SwirlTileSize = 2.0f;
    public float SwirlStength = 0.02f;
    public float SwirlSpeed = 0.05f;

    public float CloudOcclLobePower = 2.0f;
    public float CloudExtinct = 0.02f;
    private float CloudTransmissionBias = 0.1f;

    public float CloudHeight = 500.0f;
    public float CloudMinHeight = 100.0f;
    public float CloudSpawnRadius = 5000.0f;
    public Vector2 CloudMovingSpeed = new Vector2(1,0);
    public float CloudNumScale = 5.0f;
    public float CloudSpawnPosibility = 0.6f;
    public float CloudScale = 1.0f;

    private Camera m_Cam;
    
    private Dictionary<Camera, Tuple<CommandBuffer, CommandBuffer>> m_Cameras = new Dictionary<Camera, Tuple<CommandBuffer, CommandBuffer>>();

    private List<MeshRenderer> clouds;
    private bool[] _cloudVisible;

    private Material _postProcessingMaterial;

    private Material _cloudMaterial;
    // Start is called before the first frame update
    void Awake()
    {
        _postProcessingMaterial = new Material(CloudPostProcessingShader);
        _postProcessingMaterial.hideFlags = HideFlags.HideAndDontSave;
        _postProcessingMaterial.SetFloat("_WrapTile", SwirlTileSize);
        _postProcessingMaterial.SetFloat("_SwirlStrength", SwirlStength);
        _postProcessingMaterial.SetFloat("_SwirlSpeed", SwirlSpeed);
        _postProcessingMaterial.SetTexture("_WrapTex", CloudNoiseTex);

        _cloudMaterial = new Material(CloudShader);
        _cloudMaterial.hideFlags = HideFlags.HideAndDontSave;
        _cloudMaterial.SetFloat("_CloudOcclLobePower", CloudOcclLobePower);
        _cloudMaterial.SetFloat("_CloudExtinct", CloudExtinct);
        _cloudMaterial.SetFloat("_CloudTransmissionBias", CloudTransmissionBias);

        m_Cameras = new Dictionary<Camera, Tuple<CommandBuffer, CommandBuffer>>();
        Cleanup();

        /*clouds = new List<Tuple<MeshRenderer, Material>>();
        MeshFilter[] mfs = gameObject.GetComponentsInChildren<MeshFilter>();
        foreach (var mf in mfs)
        {
            var mr = mf.GetComponent<MeshRenderer>();
            clouds.Add(new Tuple<MeshRenderer, Material>(mr,mr.sharedMaterial));
        }*/
        clouds = new List<MeshRenderer>();
        MeshRenderer[] mrs = gameObject.GetComponentsInChildren<MeshRenderer>();
        if (mrs.Length <= 1)
        {
            int division = (int)(CloudSpawnRadius * 2 * CloudNumScale / 1000);
            float spacing = CloudSpawnRadius * 2 / division;
            for (int i = 0; i < division; i++)
            {
                for (int j = 0; j < division; j++)
                {
                    if (Random.value > CloudSpawnPosibility)
                    {
                        continue;
                    }
                    Vector2 basepos = new Vector2(-CloudSpawnRadius + i * spacing, -CloudSpawnRadius + j * spacing);
                    Vector2 scatterOffset = Random.insideUnitCircle * spacing / 4;
                    basepos += scatterOffset;
                    Quaternion rotation = Quaternion.Euler(0, Random.value * 360, 0);
                    float scale = Mathf.Lerp(0.8f, 1.2f, Random.value);
                    int randId = (int)(Random.value * CloudTemplates.Count);
                    randId = randId >= CloudTemplates.Count ? CloudTemplates.Count - 1 : randId;
                    GameObject cloud = Instantiate(CloudTemplates[randId], new Vector3(basepos.x, CalcHeight(basepos.x, basepos.y), basepos.y), rotation,
                        gameObject.transform) as GameObject;
                    cloud.layer = 9;
                    cloud.transform.localScale *= (scale * CloudScale);
                    MeshRenderer mr = cloud.GetComponent<MeshRenderer>();
                    mr.enabled = false;
                    clouds.Add(mr);

                }
            }
        }
        else
        {
            MeshRenderer thismr = gameObject.GetComponent<MeshRenderer>();
            foreach (var mr in mrs)
            {
                if(thismr!=mr)
                    clouds.Add(mr);
            }
        }
        _cloudVisible = new bool[clouds.Count];
        //Otherwise OnWillRender will not run
        MeshRenderer selfmr = gameObject.GetComponent<MeshRenderer>();
        if(selfmr == null)
            gameObject.AddComponent<MeshRenderer>();
    }

    void Update()
    {
        if (clouds == null) return;
        foreach (var cloud in clouds)
        {
            Vector3 cloudPos = cloud.transform.position;
            cloudPos += new Vector3(CloudMovingSpeed.x, 0, CloudMovingSpeed.y) * Time.deltaTime;
            if (cloudPos.x > CloudSpawnRadius)
            {
                cloudPos.x -= 2 * CloudSpawnRadius;
            }else if (cloudPos.x < -CloudSpawnRadius)
            {
                cloudPos.x += 2 * CloudSpawnRadius;
            }
            if (cloudPos.z > CloudSpawnRadius)
            {
                cloudPos.z -= 2 * CloudSpawnRadius;
            }
            else if (cloudPos.z < -CloudSpawnRadius)
            {
                cloudPos.z += 2 * CloudSpawnRadius;
            }

            cloudPos.y = CalcHeight(cloudPos.x, cloudPos.z);
            cloud.transform.position = cloudPos;
        }
    }

    void OnDisable()
    {

    }

    private float CalcHeight(float x, float y)
    {
        float distToCenterSqr = x * x + y * y;
        float radiusSqr = CloudSpawnRadius * CloudSpawnRadius;
        return Mathf.Lerp(CloudHeight, CloudMinHeight, distToCenterSqr / radiusSqr);

    }

    private void Cleanup()
    {
        foreach (var cam in m_Cameras)
        {
            if (cam.Key)
            {
                cam.Key.RemoveCommandBuffer(CameraEvent.AfterSkybox, cam.Value.Item1);
                cam.Key.RemoveCommandBuffer(CameraEvent.AfterSkybox, cam.Value.Item2);
            }
        }
        m_Cameras.Clear();
    }


    void OnWillRenderObject() {
        var cam = Camera.current;
        if (!cam)
            return;

        cam.depthTextureMode = DepthTextureMode.Depth;
        if (clouds==null) return;

        CommandBuffer buf = null;
        CommandBuffer buf_after = null;

        if (m_Cameras.ContainsKey(cam))
            return;

        CullClouds(cam);

        buf = new CommandBuffer();
        buf.name = "CloudPass";

        var cloudTargetID = Shader.PropertyToID("_TempCloudTarget");
        buf.GetTemporaryRT(cloudTargetID, -2, -2, 16, FilterMode.Bilinear, RenderTextureFormat.ARGBHalf);
        buf.SetRenderTarget(cloudTargetID, cloudTargetID);
        buf.ClearRenderTarget(true, true, Color.black);
        for (int i = 0; i < clouds.Count; i++)
        {
            if(_cloudVisible[i])
                buf.DrawRenderer(clouds[i], _cloudMaterial);
        }
        int cloudDownsample1 = Shader.PropertyToID("_cloudDownsample1");
        buf.GetTemporaryRT(cloudDownsample1, -4, -4, 0, FilterMode.Bilinear, RenderTextureFormat.ARGBHalf);
        int cloudDownsample2 = Shader.PropertyToID("_cloudDownsample2");
        buf.GetTemporaryRT(cloudDownsample2, -4, -4, 0, FilterMode.Bilinear, RenderTextureFormat.ARGBHalf);

        //Downsample from 2x to 4x
        buf.Blit(cloudTargetID, cloudDownsample1);

        //GaussianBlurPass1
        buf.SetGlobalTexture("_SourceTex", cloudDownsample1);
        buf.SetGlobalVector("offsets", new Vector4(4.0f / Screen.width, 0, 0, 0));
        buf.Blit(cloudDownsample1, cloudDownsample2, _postProcessingMaterial, 2);

        //GaussianBlurPass2
        buf.SetGlobalTexture("_SourceTex", cloudDownsample2);
        buf.SetGlobalVector("offsets", new Vector4(0, 4.0f / Screen.height, 0, 0));
        buf.Blit(cloudDownsample2, cloudDownsample1, _postProcessingMaterial, 2);

        //BoxBlurDepth
        buf.SetGlobalTexture("_CloudTarget", cloudDownsample1);
        buf.SetGlobalVector("_CloudTarget_TexelSize", new Vector4(4.0f / Screen.width, 4.0f / Screen.height, 0, 0));
        buf.Blit(cloudDownsample1, cloudDownsample2, _postProcessingMaterial, 0);

        //NoiseDistort
        _postProcessingMaterial.SetFloat("_WrapTile", SwirlTileSize);
        _postProcessingMaterial.SetFloat("_SwirlStrength", SwirlStength);
        _postProcessingMaterial.SetFloat("_SwirlSpeed", SwirlSpeed);
        buf.SetGlobalTexture("_SourceTex", cloudDownsample2);
        buf.Blit(cloudDownsample2, cloudDownsample1, _postProcessingMaterial, 3);
        
        buf.ReleaseTemporaryRT(cloudTargetID);
        buf.ReleaseTemporaryRT(cloudDownsample2);

        buf.SetGlobalTexture("_CloudBlured", cloudDownsample1);

        //Blend With Sky
        buf_after = new CommandBuffer();
        buf_after.name = "CompositeCloud";
        buf_after.SetGlobalTexture("_Background", BuiltinRenderTextureType.CurrentActive);
        buf_after.Blit(BuiltinRenderTextureType.CurrentActive, BuiltinRenderTextureType.CameraTarget, _postProcessingMaterial, 1);
        
        cam.AddCommandBuffer(CameraEvent.BeforeForwardOpaque, buf);
        cam.AddCommandBuffer(CameraEvent.AfterForwardAlpha, buf_after);

        m_Cameras[cam] = new Tuple<CommandBuffer, CommandBuffer>(buf, buf_after);
    }

    private void CullClouds(Camera cam)
    {
        for (int i = 0; i < clouds.Count; i++)
        {
            Vector3 pos = cam.WorldToScreenPoint(clouds[i].transform.position);
            if (pos.x > -100 && pos.x < (cam.pixelWidth + 100) && pos.y > -100 && pos.y < (cam.pixelHeight + 100) &&
                pos.z > -300)
            {
                _cloudVisible[i] = true;
            } else
            {
                _cloudVisible[i] = false;
            }
        }
    }
}
