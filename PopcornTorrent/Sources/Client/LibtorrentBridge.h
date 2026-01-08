//
//  LibtorrentBridge.h
//  Thin C bridge for libtorrent to enable Swift interop
//

#ifndef LibtorrentBridge_h
#define LibtorrentBridge_h

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque types for C++ objects
typedef void* lt_session_t;
typedef void* lt_torrent_handle_t;
typedef void* lt_add_torrent_params_t;
typedef void* lt_alert_t;
typedef void* lt_settings_pack_t;
typedef void* lt_torrent_info_t;

// Error handling
typedef struct {
    int code;
    char message[512];
} lt_error_t;

// Torrent status struct (C-compatible)
typedef struct {
    float progress;
    int64_t total_wanted;
    int64_t total_wanted_done;
    int download_rate;
    int upload_rate;
    int num_seeds;
    int num_peers;
    bool is_finished;
    bool has_metadata;
} lt_torrent_status_t;

// Piece index
typedef int32_t lt_piece_index_t;
typedef int32_t lt_file_index_t;

// Alert types
typedef enum {
    lt_alert_none = 0,
    lt_alert_metadata_received = 1,
    lt_alert_piece_finished = 2,
    lt_alert_torrent_finished = 3,
    lt_alert_save_resume_data = 4,
    lt_alert_file_error = 5,
} lt_alert_type_t;

// Alert info
typedef struct {
    lt_alert_type_t type;
    lt_torrent_handle_t handle;
    lt_piece_index_t piece_index;
    char message[512];
    void* params;  // For save_resume_data_alert
} lt_alert_info_t;

// Session functions
lt_session_t lt_session_create(lt_settings_pack_t settings, lt_error_t* error);
void lt_session_destroy(lt_session_t session);
void lt_session_apply_settings(lt_session_t session, lt_settings_pack_t settings);
void lt_session_add_extension_smart_ban(lt_session_t session);
void lt_session_add_extension_ut_metadata(lt_session_t session);
lt_torrent_handle_t lt_session_add_torrent(lt_session_t session, lt_add_torrent_params_t params, lt_error_t* error);
void lt_session_remove_torrent(lt_session_t session, lt_torrent_handle_t handle);
bool lt_session_wait_for_alert(lt_session_t session, int timeout_ms);
int lt_session_pop_alerts(lt_session_t session, lt_alert_info_t* alerts, int max_alerts);

// Settings pack functions
lt_settings_pack_t lt_settings_pack_create_default(void);
void lt_settings_pack_destroy(lt_settings_pack_t pack);
void lt_settings_pack_set_str(lt_settings_pack_t pack, int name, const char* value);
void lt_settings_pack_set_int(lt_settings_pack_t pack, int name, int value);
void lt_settings_pack_set_bool(lt_settings_pack_t pack, int name, bool value);

// Add torrent params functions
lt_add_torrent_params_t lt_add_torrent_params_create(void);
void lt_add_torrent_params_destroy(lt_add_torrent_params_t params);
void lt_add_torrent_params_set_save_path(lt_add_torrent_params_t params, const char* path);
bool lt_add_torrent_params_parse_magnet(lt_add_torrent_params_t params, const char* uri, lt_error_t* error);
bool lt_add_torrent_params_load_torrent_file(lt_add_torrent_params_t params, const char* path, lt_error_t* error);
void lt_add_torrent_params_set_ti(lt_add_torrent_params_t params, lt_torrent_info_t ti);
bool lt_add_torrent_params_load_resume_data(lt_add_torrent_params_t params, const uint8_t* data, int64_t size, lt_error_t* error);

// Torrent handle functions
bool lt_torrent_handle_is_valid(lt_torrent_handle_t handle);
lt_torrent_status_t lt_torrent_handle_status(lt_torrent_handle_t handle);
void lt_torrent_handle_pause(lt_torrent_handle_t handle);
void lt_torrent_handle_resume(lt_torrent_handle_t handle);
void lt_torrent_handle_set_sequential_download(lt_torrent_handle_t handle, bool sequential);
void lt_torrent_handle_set_max_connections(lt_torrent_handle_t handle, int limit);
void lt_torrent_handle_set_max_uploads(lt_torrent_handle_t handle, int limit);
void lt_torrent_handle_piece_priority(lt_torrent_handle_t handle, lt_piece_index_t piece, int priority);
void lt_torrent_handle_set_piece_deadline(lt_torrent_handle_t handle, lt_piece_index_t piece, int deadline_ms);
void lt_torrent_handle_clear_piece_deadlines(lt_torrent_handle_t handle);
bool lt_torrent_handle_have_piece(lt_torrent_handle_t handle, lt_piece_index_t piece);
void lt_torrent_handle_file_priority(lt_torrent_handle_t handle, lt_file_index_t file, int priority);
void lt_torrent_handle_save_resume_data(lt_torrent_handle_t handle);
void lt_torrent_handle_flush_cache(lt_torrent_handle_t handle);
bool lt_torrent_handle_need_save_resume_data(lt_torrent_handle_t handle);
void lt_torrent_handle_get_info_hash_hex(lt_torrent_handle_t handle, char* out, int out_size);
lt_torrent_info_t lt_torrent_handle_get_torrent_file(lt_torrent_handle_t handle);

// Torrent info functions
int lt_torrent_info_num_files(lt_torrent_info_t ti);
void lt_torrent_info_file_name(lt_torrent_info_t ti, lt_file_index_t index, char* out, int out_size);
int64_t lt_torrent_info_file_size(lt_torrent_info_t ti, lt_file_index_t index);
void lt_torrent_info_file_path(lt_torrent_info_t ti, lt_file_index_t index, char* out, int out_size);
int64_t lt_torrent_info_piece_length(lt_torrent_info_t ti);
int lt_torrent_info_num_pieces(lt_torrent_info_t ti);

// Resume data functions
bool lt_save_resume_data_to_file(void* params, const char* path, lt_error_t* error);

// Constants
enum lt_settings_pack_int_types {
    lt_settings_alert_mask = 0,
    lt_settings_max_retry_port_bind = 1,
    lt_settings_file_pool_size = 2,
};

enum lt_settings_pack_bool_types {
    lt_settings_listen_system_port_fallback = 0,
    lt_settings_suggest_read_cache = 1,
    lt_settings_enable_upnp = 2,
    lt_settings_enable_natpmp = 3,
    lt_settings_upnp_ignore_nonrouters = 4,
};

enum lt_settings_pack_str_types {
    lt_settings_dht_bootstrap_nodes = 0,
    lt_settings_listen_interfaces = 1,
};

enum lt_download_priority {
    lt_priority_dont_download = 0,
    lt_priority_low = 1,
    lt_priority_default = 4,
    lt_priority_top = 7,
};

#ifdef __cplusplus
}
#endif

#endif /* LibtorrentBridge_h */
