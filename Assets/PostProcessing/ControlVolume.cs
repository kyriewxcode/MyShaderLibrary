using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class ControlVolume : MonoBehaviour
{
    private Volume volume;
    private List<VolumeComponent> components;

    [Header("Scan")] public float scanMaxDistance = 1f;
    public float scanSpeed = 1f;
    private Scan scanComponent;

    void Start()
    {
        volume = GetComponent<Volume>();
        components = volume.profile.components;
        foreach (var component in components)
        {
            if (component.GetType() == typeof(Scan))
                scanComponent = (Scan)component;
        }
    }

    void Update()
    {
        GetClickPoint();
    }

    void GetClickPoint()
    {
        if (Input.GetMouseButtonDown(0))
        {
            Ray ray = Camera.main.ScreenPointToRay(Input.mousePosition);
            RaycastHit hit;
            if (Physics.Raycast(ray, out hit))
            {
                scanComponent.clickPos.value = hit.point;
                StartCoroutine(ScanDistance());
            }
        }
    }

    IEnumerator ScanDistance()
    {
        float scanDistance = 0f;
        while (scanDistance < scanMaxDistance)
        {
            scanDistance += Time.deltaTime * scanSpeed;
            scanComponent.scanDistace.value = scanDistance;
            yield return new WaitForEndOfFrame();
        }

        scanComponent.scanDistace.value = 0f;
    }
}