using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SunRotate : MonoBehaviour
{
    public float speed = 0.01f;

    // Update is called once per frame
    void Update()
    {
        Vector3 rotationEuler = transform.rotation.eulerAngles;
        rotationEuler.y += speed * Time.deltaTime;
        transform.rotation = Quaternion.Euler(rotationEuler);
    }
}
