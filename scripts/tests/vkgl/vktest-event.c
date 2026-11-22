/*
 * Vulkan host Event state-machine integration test.
 *
 * Run with VK_ICD_FILENAMES/VK_DRIVER_FILES selecting exactly one ICD and
 * NDEVICE_SELECT=1.  The test refuses anything other than the real LG110
 * vkgl device, so a lavapipe/llvmpipe fallback cannot produce a false pass.
 */
#include <vulkan/vulkan.h>

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define LG110_NAME "LoongGPU LG110 (vkgl GLES2)"

static unsigned int failures;

static const char *result_name(VkResult result)
{
    switch (result) {
    case VK_SUCCESS:
        return "VK_SUCCESS";
    case VK_NOT_READY:
        return "VK_NOT_READY";
    case VK_TIMEOUT:
        return "VK_TIMEOUT";
    case VK_EVENT_SET:
        return "VK_EVENT_SET";
    case VK_EVENT_RESET:
        return "VK_EVENT_RESET (UNSIGNALLED)";
    case VK_INCOMPLETE:
        return "VK_INCOMPLETE";
    case VK_ERROR_OUT_OF_HOST_MEMORY:
        return "VK_ERROR_OUT_OF_HOST_MEMORY";
    case VK_ERROR_OUT_OF_DEVICE_MEMORY:
        return "VK_ERROR_OUT_OF_DEVICE_MEMORY";
    case VK_ERROR_INITIALIZATION_FAILED:
        return "VK_ERROR_INITIALIZATION_FAILED";
    case VK_ERROR_DEVICE_LOST:
        return "VK_ERROR_DEVICE_LOST";
    case VK_ERROR_EXTENSION_NOT_PRESENT:
        return "VK_ERROR_EXTENSION_NOT_PRESENT";
    case VK_ERROR_INCOMPATIBLE_DRIVER:
        return "VK_ERROR_INCOMPATIBLE_DRIVER";
    default:
        return "UNRECOGNIZED_VkResult";
    }
}

static int expect_result(const char *call, VkResult actual, VkResult expected)
{
    const int matches = actual == expected;

    printf("%s = %s (%d), expected %s (%d): %s\n",
           call, result_name(actual), (int)actual,
           result_name(expected), (int)expected,
           matches ? "OK" : "MISMATCH");
    if (!matches) {
        fprintf(stderr, "FAIL: %s returned %d, expected %d\n",
                call, (int)actual, (int)expected);
        ++failures;
    }
    return matches;
}

static void expect_event_status(VkDevice device, VkEvent event,
                                unsigned int index, const char *stage,
                                VkResult expected)
{
    char label[128];
    VkResult actual;

    snprintf(label, sizeof(label), "vkGetEventStatus(event[%u], %s)",
             index, stage);
    actual = vkGetEventStatus(device, event);
    expect_result(label, actual, expected);
}

int main(void)
{
    const char *icd = getenv("VK_ICD_FILENAMES");
    const char *driver_files = getenv("VK_DRIVER_FILES");
    const char *nodevice_select = getenv("NODEVICE_SELECT");
    VkApplicationInfo app = {
        .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = "vktest-event",
        .applicationVersion = 1,
        .apiVersion = VK_API_VERSION_1_0,
    };
    VkInstanceCreateInfo instance_info = {
        .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &app,
    };
    VkEventCreateInfo event_info = {
        .sType = VK_STRUCTURE_TYPE_EVENT_CREATE_INFO,
    };
    VkInstance instance = VK_NULL_HANDLE;
    VkDevice device = VK_NULL_HANDLE;
    VkPhysicalDevice *physical = NULL;
    VkQueueFamilyProperties *queues = NULL;
    VkEvent events[2] = { VK_NULL_HANDLE, VK_NULL_HANDLE };
    VkEvent recreated = VK_NULL_HANDLE;
    uint32_t physical_count = 0;
    uint32_t queue_count = 0;
    uint32_t queue_index = UINT32_MAX;
    VkResult result;
    unsigned int i;

    printf("VK_ICD_FILENAMES=%s\n", icd ? icd : "(unset)");
    printf("VK_DRIVER_FILES=%s\n", driver_files ? driver_files : "(unset)");
    printf("NODEVICE_SELECT=%s\n", nodevice_select ? nodevice_select : "(unset)");
    /* NDEVICE_SELECT is a launcher requirement and may be consumed before
     * main; the recorded command line, rather than this runtime check, proves
     * that it was supplied. */
    if (!icd || !*icd || !driver_files || strcmp(icd, driver_files) != 0) {
        fprintf(stderr,
                "FAIL: set matching VK_ICD_FILENAMES and VK_DRIVER_FILES\n");
        return 1;
    }

    result = vkCreateInstance(&instance_info, NULL, &instance);
    if (!expect_result("vkCreateInstance", result, VK_SUCCESS))
        goto done;

    result = vkEnumeratePhysicalDevices(instance, &physical_count, NULL);
    expect_result("vkEnumeratePhysicalDevices(count)", result, VK_SUCCESS);
    printf("physicalDeviceCount=%u\n", physical_count);
    if (result != VK_SUCCESS || physical_count != 1) {
        fprintf(stderr, "FAIL: expected exactly one physical device\n");
        ++failures;
        goto done;
    }

    physical = calloc(physical_count, sizeof(*physical));
    if (!physical) {
        fprintf(stderr, "FAIL: calloc physical devices\n");
        ++failures;
        goto done;
    }
    result = vkEnumeratePhysicalDevices(instance, &physical_count, physical);
    if (!expect_result("vkEnumeratePhysicalDevices(list)", result, VK_SUCCESS))
        goto done;

    for (i = 0; i < physical_count; ++i) {
        VkPhysicalDeviceProperties properties;

        memset(&properties, 0, sizeof(properties));
        vkGetPhysicalDeviceProperties(physical[i], &properties);
        printf("device[%u]: deviceName=%s; deviceType=%d; vendorID=0x%04x; "
               "deviceID=0x%04x; apiVersion=%u.%u.%u\n",
               i, properties.deviceName, (int)properties.deviceType,
               properties.vendorID, properties.deviceID,
               VK_VERSION_MAJOR(properties.apiVersion),
               VK_VERSION_MINOR(properties.apiVersion),
               VK_VERSION_PATCH(properties.apiVersion));
        if (strcmp(properties.deviceName, LG110_NAME) != 0 ||
            properties.deviceType == VK_PHYSICAL_DEVICE_TYPE_CPU ||
            properties.vendorID != 0x0014 || properties.deviceID != 0x7a25) {
            fprintf(stderr,
                    "FAIL: refusing non-LG110, CPU, or unexpected vendor/device\n");
            ++failures;
            goto done;
        }
    }

    vkGetPhysicalDeviceQueueFamilyProperties(physical[0], &queue_count, NULL);
    printf("queueFamilyCount=%u\n", queue_count);
    if (!queue_count) {
        fprintf(stderr, "FAIL: no queue families\n");
        ++failures;
        goto done;
    }
    queues = calloc(queue_count, sizeof(*queues));
    if (!queues) {
        fprintf(stderr, "FAIL: calloc queue families\n");
        ++failures;
        goto done;
    }
    vkGetPhysicalDeviceQueueFamilyProperties(physical[0], &queue_count, queues);
    for (i = 0; i < queue_count; ++i) {
        if (queues[i].queueCount) {
            queue_index = i;
            break;
        }
    }
    if (queue_index == UINT32_MAX) {
        fprintf(stderr, "FAIL: no usable queue\n");
        ++failures;
        goto done;
    }
    printf("queueFamilyIndex=%u\n", queue_index);

    {
        float priority = 1.0f;
        VkDeviceQueueCreateInfo queue_info = {
            .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .queueFamilyIndex = queue_index,
            .queueCount = 1,
            .pQueuePriorities = &priority,
        };
        VkDeviceCreateInfo device_info = {
            .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            .queueCreateInfoCount = 1,
            .pQueueCreateInfos = &queue_info,
        };

        result = vkCreateDevice(physical[0], &device_info, NULL, &device);
        if (!expect_result("vkCreateDevice", result, VK_SUCCESS))
            goto done;
    }

    for (i = 0; i < 2; ++i) {
        char label[64];

        snprintf(label, sizeof(label), "vkCreateEvent(event[%u])", i);
        result = vkCreateEvent(device, &event_info, NULL, &events[i]);
        if (!expect_result(label, result, VK_SUCCESS))
            goto done;
        expect_event_status(device, events[i], i, "new", VK_EVENT_RESET);
    }

    result = vkSetEvent(device, events[0]);
    expect_result("vkSetEvent(event[0], first)", result, VK_SUCCESS);
    expect_event_status(device, events[0], 0, "after first Set", VK_EVENT_SET);
    expect_event_status(device, events[1], 1, "event[0] Set must not leak",
                        VK_EVENT_RESET);

    result = vkSetEvent(device, events[0]);
    expect_result("vkSetEvent(event[0], repeated)", result, VK_SUCCESS);
    expect_event_status(device, events[0], 0, "after repeated Set", VK_EVENT_SET);
    expect_event_status(device, events[1], 1, "still independent",
                        VK_EVENT_RESET);

    result = vkSetEvent(device, events[1]);
    expect_result("vkSetEvent(event[1], first)", result, VK_SUCCESS);
    expect_event_status(device, events[0], 0, "both Set, event[0]", VK_EVENT_SET);
    expect_event_status(device, events[1], 1, "both Set, event[1]", VK_EVENT_SET);

    result = vkResetEvent(device, events[0]);
    expect_result("vkResetEvent(event[0], first)", result, VK_SUCCESS);
    expect_event_status(device, events[0], 0, "after first Reset", VK_EVENT_RESET);
    expect_event_status(device, events[1], 1, "event[0] Reset must not leak",
                        VK_EVENT_SET);

    result = vkResetEvent(device, events[0]);
    expect_result("vkResetEvent(event[0], repeated)", result, VK_SUCCESS);
    expect_event_status(device, events[0], 0, "after repeated Reset",
                        VK_EVENT_RESET);
    expect_event_status(device, events[1], 1, "event[1] remains Set",
                        VK_EVENT_SET);

    result = vkResetEvent(device, events[1]);
    expect_result("vkResetEvent(event[1], first)", result, VK_SUCCESS);
    result = vkResetEvent(device, events[1]);
    expect_result("vkResetEvent(event[1], repeated)", result, VK_SUCCESS);
    expect_event_status(device, events[0], 0, "both Reset, event[0]",
                        VK_EVENT_RESET);
    expect_event_status(device, events[1], 1, "both Reset, event[1]",
                        VK_EVENT_RESET);

    result = vkSetEvent(device, events[0]);
    expect_result("vkSetEvent(event[0], before destroy)", result, VK_SUCCESS);
    result = vkSetEvent(device, events[1]);
    expect_result("vkSetEvent(event[1], before destroy)", result, VK_SUCCESS);
    for (i = 0; i < 2; ++i) {
        printf("vkDestroyEvent(event[%u], signaled) called\n", i);
        vkDestroyEvent(device, events[i], NULL);
        events[i] = VK_NULL_HANDLE;
    }

    /* Destruction must not leave state that a newly allocated Event inherits. */
    result = vkCreateEvent(device, &event_info, NULL, &recreated);
    if (expect_result("vkCreateEvent(recreated after destroys)", result,
                      VK_SUCCESS)) {
        expect_event_status(device, recreated, 0, "recreated after destroys",
                            VK_EVENT_RESET);
        printf("vkDestroyEvent(recreated) called\n");
        vkDestroyEvent(device, recreated, NULL);
        recreated = VK_NULL_HANDLE;
    }

 done:
    for (i = 0; i < 2; ++i) {
        if (events[i] != VK_NULL_HANDLE) {
            printf("cleanup: vkDestroyEvent(event[%u]) called\n", i);
            vkDestroyEvent(device, events[i], NULL);
        }
    }
    if (recreated != VK_NULL_HANDLE) {
        printf("cleanup: vkDestroyEvent(recreated) called\n");
        vkDestroyEvent(device, recreated, NULL);
    }
    if (device != VK_NULL_HANDLE)
        vkDestroyDevice(device, NULL);
    if (instance != VK_NULL_HANDLE)
        vkDestroyInstance(instance, NULL);
    free(queues);
    free(physical);

    printf("event_semantics=%s mismatches=%u\n",
           failures ? "FAIL" : "PASS", failures);
    return failures ? 2 : 0;
}
