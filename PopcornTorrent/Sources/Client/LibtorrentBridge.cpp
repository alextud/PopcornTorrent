//
//  LibtorrentBridge.cpp
//  C bridge implementation for libtorrent
//

#include "LibtorrentBridge.h"
#include <libtorrent/session.hpp>
#include <libtorrent/torrent_handle.hpp>
#include <libtorrent/torrent_info.hpp>
#include <libtorrent/add_torrent_params.hpp>
#include <libtorrent/magnet_uri.hpp>
#include <libtorrent/alert.hpp>
#include <libtorrent/alert_types.hpp>
#include <libtorrent/read_resume_data.hpp>
#include <libtorrent/write_resume_data.hpp>
#include <libtorrent/settings_pack.hpp>
#include <libtorrent/extensions/smart_ban.hpp>
#include <libtorrent/extensions/ut_metadata.hpp>
#include <libtorrent/hex.hpp>
#include <string>
#include <cstring>
#include <vector>
#include <fstream>

using namespace libtorrent;

// Helper to copy error
static void set_error(lt_error_t* error, const error_code& ec) {
    if (error && ec) {
        error->code = ec.value();
        strncpy(error->message, ec.message().c_str(), sizeof(error->message) - 1);
        error->message[sizeof(error->message) - 1] = '\0';
    } else if (error) {
        error->code = 0;
        error->message[0] = '\0';
    }
}

// Session functions
lt_session_t lt_session_create(lt_settings_pack_t settings, lt_error_t* error) {
    try {
        auto* session_ptr = new session();
        if (settings) {
            session_ptr->apply_settings(*static_cast<settings_pack*>(settings));
        }
        if (error) {
            error->code = 0;
            error->message[0] = '\0';
        }
        return session_ptr;
    } catch (const std::exception& e) {
        if (error) {
            error->code = -1;
            strncpy(error->message, e.what(), sizeof(error->message) - 1);
            error->message[sizeof(error->message) - 1] = '\0';
        }
        return nullptr;
    }
}

void lt_session_destroy(lt_session_t session) {
    delete static_cast<session*>(session);
}

void lt_session_apply_settings(lt_session_t session, lt_settings_pack_t settings) {
    if (session && settings) {
        static_cast<session*>(session)->apply_settings(*static_cast<settings_pack*>(settings));
    }
}

void lt_session_add_extension_smart_ban(lt_session_t session) {
    if (session) {
        static_cast<session*>(session)->add_extension(&create_smart_ban_plugin);
    }
}

void lt_session_add_extension_ut_metadata(lt_session_t session) {
    if (session) {
        static_cast<session*>(session)->add_extension(&create_ut_metadata_plugin);
    }
}

lt_torrent_handle_t lt_session_add_torrent(lt_session_t session, lt_add_torrent_params_t params, lt_error_t* error) {
    if (!session || !params) {
        if (error) {
            error->code = -1;
            strncpy(error->message, "Invalid session or params", sizeof(error->message) - 1);
        }
        return nullptr;
    }

    try {
        error_code ec;
        torrent_handle handle = static_cast<session*>(session)->add_torrent(*static_cast<add_torrent_params*>(params), ec);
        set_error(error, ec);
        if (ec) return nullptr;
        return new torrent_handle(handle);
    } catch (const std::exception& e) {
        if (error) {
            error->code = -1;
            strncpy(error->message, e.what(), sizeof(error->message) - 1);
            error->message[sizeof(error->message) - 1] = '\0';
        }
        return nullptr;
    }
}

void lt_session_remove_torrent(lt_session_t session, lt_torrent_handle_t handle) {
    if (session && handle) {
        static_cast<session*>(session)->remove_torrent(*static_cast<torrent_handle*>(handle));
    }
}

bool lt_session_wait_for_alert(lt_session_t session, int timeout_ms) {
    if (!session) return false;
    time_duration max_wait = milliseconds(timeout_ms);
    const alert* ptr = static_cast<session*>(session)->wait_for_alert(max_wait);
    return ptr != nullptr;
}

int lt_session_pop_alerts(lt_session_t session, lt_alert_info_t* alerts, int max_alerts) {
    if (!session || !alerts) return 0;

    std::vector<alert*> deque;
    static_cast<session*>(session)->pop_alerts(&deque);

    int count = 0;
    for (alert* a : deque) {
        if (count >= max_alerts) break;

        alerts[count].handle = nullptr;
        alerts[count].piece_index = -1;
        alerts[count].params = nullptr;
        alerts[count].message[0] = '\0';

        switch (a->type()) {
            case metadata_received_alert::alert_type:
                alerts[count].type = lt_alert_metadata_received;
                alerts[count].handle = new torrent_handle(((metadata_received_alert*)a)->handle);
                break;
            case piece_finished_alert::alert_type:
                alerts[count].type = lt_alert_piece_finished;
                alerts[count].handle = new torrent_handle(((piece_finished_alert*)a)->handle);
                alerts[count].piece_index = static_cast<int>(((piece_finished_alert*)a)->piece_index);
                break;
            case torrent_finished_alert::alert_type:
                alerts[count].type = lt_alert_torrent_finished;
                alerts[count].handle = new torrent_handle(((torrent_finished_alert*)a)->handle);
                break;
            case save_resume_data_alert::alert_type: {
                alerts[count].type = lt_alert_save_resume_data;
                alerts[count].handle = new torrent_handle(((save_resume_data_alert*)a)->handle);
                // Store params pointer for later use
                alerts[count].params = new add_torrent_params(((save_resume_data_alert*)a)->params);
                break;
            }
            case file_error_alert::alert_type:
                alerts[count].type = lt_alert_file_error;
                alerts[count].handle = new torrent_handle(((file_error_alert*)a)->handle);
                strncpy(alerts[count].message, a->message().c_str(), sizeof(alerts[count].message) - 1);
                alerts[count].message[sizeof(alerts[count].message) - 1] = '\0';
                break;
            default:
                continue;  // Skip unknown alerts
        }
        count++;
    }

    return count;
}

// Settings pack functions
lt_settings_pack_t lt_settings_pack_create_default() {
    return new settings_pack(default_settings());
}

void lt_settings_pack_destroy(lt_settings_pack_t pack) {
    delete static_cast<settings_pack*>(pack);
}

void lt_settings_pack_set_str(lt_settings_pack_t pack, int name, const char* value) {
    if (!pack || !value) return;
    auto* sp = static_cast<settings_pack*>(pack);
    switch (name) {
        case lt_settings_dht_bootstrap_nodes:
            sp->set_str(settings_pack::dht_bootstrap_nodes, value);
            break;
        case lt_settings_listen_interfaces:
            sp->set_str(settings_pack::listen_interfaces, value);
            break;
    }
}

void lt_settings_pack_set_int(lt_settings_pack_t pack, int name, int value) {
    if (!pack) return;
    auto* sp = static_cast<settings_pack*>(pack);
    switch (name) {
        case lt_settings_alert_mask:
            sp->set_int(settings_pack::alert_mask, value);
            break;
        case lt_settings_max_retry_port_bind:
            sp->set_int(settings_pack::max_retry_port_bind, value);
            break;
        case lt_settings_file_pool_size:
            sp->set_int(settings_pack::file_pool_size, value);
            break;
    }
}

void lt_settings_pack_set_bool(lt_settings_pack_t pack, int name, bool value) {
    if (!pack) return;
    auto* sp = static_cast<settings_pack*>(pack);
    switch (name) {
        case lt_settings_listen_system_port_fallback:
            sp->set_bool(settings_pack::listen_system_port_fallback, value);
            break;
        case lt_settings_suggest_read_cache:
            sp->set_bool(settings_pack::suggest_read_cache, value);
            break;
        case lt_settings_enable_upnp:
            sp->set_bool(settings_pack::enable_upnp, value);
            break;
        case lt_settings_enable_natpmp:
            sp->set_bool(settings_pack::enable_natpmp, value);
            break;
        case lt_settings_upnp_ignore_nonrouters:
            sp->set_bool(settings_pack::upnp_ignore_nonrouters, value);
            break;
    }
}

// Add torrent params functions
lt_add_torrent_params_t lt_add_torrent_params_create() {
    return new add_torrent_params();
}

void lt_add_torrent_params_destroy(lt_add_torrent_params_t params) {
    delete static_cast<add_torrent_params*>(params);
}

void lt_add_torrent_params_set_save_path(lt_add_torrent_params_t params, const char* path) {
    if (params && path) {
        static_cast<add_torrent_params*>(params)->save_path = path;
    }
}

bool lt_add_torrent_params_parse_magnet(lt_add_torrent_params_t params, const char* uri, lt_error_t* error) {
    if (!params || !uri) {
        if (error) {
            error->code = -1;
            strncpy(error->message, "Invalid params or URI", sizeof(error->message) - 1);
        }
        return false;
    }

    try {
        error_code ec;
        *static_cast<add_torrent_params*>(params) = parse_magnet_uri(uri, ec);
        set_error(error, ec);
        return !ec;
    } catch (const std::exception& e) {
        if (error) {
            error->code = -1;
            strncpy(error->message, e.what(), sizeof(error->message) - 1);
            error->message[sizeof(error->message) - 1] = '\0';
        }
        return false;
    }
}

bool lt_add_torrent_params_load_torrent_file(lt_add_torrent_params_t params, const char* path, lt_error_t* error) {
    if (!params || !path) {
        if (error) {
            error->code = -1;
            strncpy(error->message, "Invalid params or path", sizeof(error->message) - 1);
        }
        return false;
    }

    try {
        error_code ec;
        auto ti = std::make_shared<torrent_info>(path, ec);
        if (ec) {
            set_error(error, ec);
            return false;
        }
        static_cast<add_torrent_params*>(params)->ti = ti;
        if (error) {
            error->code = 0;
            error->message[0] = '\0';
        }
        return true;
    } catch (const std::exception& e) {
        if (error) {
            error->code = -1;
            strncpy(error->message, e.what(), sizeof(error->message) - 1);
            error->message[sizeof(error->message) - 1] = '\0';
        }
        return false;
    }
}

void lt_add_torrent_params_set_ti(lt_add_torrent_params_t params, lt_torrent_info_t ti) {
    if (params && ti) {
        // Note: This is a simplified version - in practice you'd need to handle shared_ptr properly
    }
}

bool lt_add_torrent_params_load_resume_data(lt_add_torrent_params_t params, const uint8_t* data, int64_t size, lt_error_t* error) {
    if (!params || !data || size <= 0) {
        if (error) {
            error->code = -1;
            strncpy(error->message, "Invalid params or data", sizeof(error->message) - 1);
        }
        return false;
    }

    try {
        error_code ec;
        std::vector<char> buf(data, data + size);
        *static_cast<add_torrent_params*>(params) = read_resume_data(buf, ec);
        set_error(error, ec);
        return !ec;
    } catch (const std::exception& e) {
        if (error) {
            error->code = -1;
            strncpy(error->message, e.what(), sizeof(error->message) - 1);
            error->message[sizeof(error->message) - 1] = '\0';
        }
        return false;
    }
}

// Torrent handle functions
bool lt_torrent_handle_is_valid(lt_torrent_handle_t handle) {
    return handle && static_cast<torrent_handle*>(handle)->is_valid();
}

lt_torrent_status_t lt_torrent_handle_status(lt_torrent_handle_t handle) {
    lt_torrent_status_t status = {0};
    if (!handle) return status;

    torrent_status ts = static_cast<torrent_handle*>(handle)->status();
    status.progress = ts.progress;
    status.total_wanted = ts.total_wanted;
    status.total_wanted_done = ts.total_wanted_done;
    status.download_rate = ts.download_rate;
    status.upload_rate = ts.upload_rate;
    status.num_seeds = ts.num_seeds;
    status.num_peers = ts.num_peers;
    status.is_finished = ts.is_finished;
    status.has_metadata = ts.has_metadata;

    return status;
}

void lt_torrent_handle_pause(lt_torrent_handle_t handle) {
    if (handle) {
        static_cast<torrent_handle*>(handle)->pause(torrent_handle::graceful_pause);
    }
}

void lt_torrent_handle_resume(lt_torrent_handle_t handle) {
    if (handle) {
        static_cast<torrent_handle*>(handle)->resume();
    }
}

void lt_torrent_handle_set_sequential_download(lt_torrent_handle_t handle, bool sequential) {
    if (handle) {
        if (sequential) {
            static_cast<torrent_handle*>(handle)->set_flags(torrent_flags::sequential_download);
        } else {
            static_cast<torrent_handle*>(handle)->unset_flags(torrent_flags::sequential_download);
        }
    }
}

void lt_torrent_handle_set_max_connections(lt_torrent_handle_t handle, int limit) {
    if (handle) {
        static_cast<torrent_handle*>(handle)->set_max_connections(limit);
    }
}

void lt_torrent_handle_set_max_uploads(lt_torrent_handle_t handle, int limit) {
    if (handle) {
        static_cast<torrent_handle*>(handle)->set_max_uploads(limit);
    }
}

void lt_torrent_handle_piece_priority(lt_torrent_handle_t handle, lt_piece_index_t piece, int priority) {
    if (handle) {
        static_cast<torrent_handle*>(handle)->piece_priority(piece_index_t(piece), download_priority_t(priority));
    }
}

void lt_torrent_handle_set_piece_deadline(lt_torrent_handle_t handle, lt_piece_index_t piece, int deadline_ms) {
    if (handle) {
        static_cast<torrent_handle*>(handle)->set_piece_deadline(piece_index_t(piece), deadline_ms, torrent_handle::alert_when_available);
    }
}

void lt_torrent_handle_clear_piece_deadlines(lt_torrent_handle_t handle) {
    if (handle) {
        static_cast<torrent_handle*>(handle)->clear_piece_deadlines();
    }
}

bool lt_torrent_handle_have_piece(lt_torrent_handle_t handle, lt_piece_index_t piece) {
    if (!handle) return false;
    return static_cast<torrent_handle*>(handle)->have_piece(piece_index_t(piece));
}

void lt_torrent_handle_file_priority(lt_torrent_handle_t handle, lt_file_index_t file, int priority) {
    if (handle) {
        std::vector<download_priority_t> priorities = static_cast<torrent_handle*>(handle)->get_file_priorities();
        if (file >= 0 && file < static_cast<int>(priorities.size())) {
            priorities[file] = download_priority_t(priority);
            static_cast<torrent_handle*>(handle)->prioritize_files(priorities);
        }
    }
}

void lt_torrent_handle_save_resume_data(lt_torrent_handle_t handle) {
    if (handle) {
        static_cast<torrent_handle*>(handle)->save_resume_data();
    }
}

void lt_torrent_handle_flush_cache(lt_torrent_handle_t handle) {
    if (handle) {
        static_cast<torrent_handle*>(handle)->flush_cache();
    }
}

bool lt_torrent_handle_need_save_resume_data(lt_torrent_handle_t handle) {
    if (!handle) return false;
    return static_cast<torrent_handle*>(handle)->need_save_resume_data();
}

void lt_torrent_handle_get_info_hash_hex(lt_torrent_handle_t handle, char* out, int out_size) {
    if (!handle || !out || out_size <= 0) return;
    std::string hex = aux::to_hex(static_cast<torrent_handle*>(handle)->info_hash());
    strncpy(out, hex.c_str(), out_size - 1);
    out[out_size - 1] = '\0';
}

lt_torrent_info_t lt_torrent_handle_get_torrent_file(lt_torrent_handle_t handle) {
    if (!handle) return nullptr;
    // Return the raw pointer - caller should not delete it
    return (lt_torrent_info_t)static_cast<torrent_handle*>(handle)->torrent_file().get();
}

// Torrent info functions
int lt_torrent_info_num_files(lt_torrent_info_t ti) {
    if (!ti) return 0;
    return static_cast<const torrent_info*>(ti)->num_files();
}

void lt_torrent_info_file_name(lt_torrent_info_t ti, lt_file_index_t index, char* out, int out_size) {
    if (!ti || !out || out_size <= 0) return;
    const torrent_info* info = static_cast<const torrent_info*>(ti);
    string_view name = info->files().file_name(file_index_t(index));
    strncpy(out, name.data(), std::min(out_size - 1, static_cast<int>(name.size())));
    out[std::min(out_size - 1, static_cast<int>(name.size()))] = '\0';
}

int64_t lt_torrent_info_file_size(lt_torrent_info_t ti, lt_file_index_t index) {
    if (!ti) return 0;
    return static_cast<const torrent_info*>(ti)->files().file_size(file_index_t(index));
}

void lt_torrent_info_file_path(lt_torrent_info_t ti, lt_file_index_t index, char* out, int out_size) {
    if (!ti || !out || out_size <= 0) return;
    const torrent_info* info = static_cast<const torrent_info*>(ti);
    std::string path = info->files().file_path(file_index_t(index));
    strncpy(out, path.c_str(), out_size - 1);
    out[out_size - 1] = '\0';
}

int64_t lt_torrent_info_piece_length(lt_torrent_info_t ti) {
    if (!ti) return 0;
    return static_cast<const torrent_info*>(ti)->piece_length();
}

int lt_torrent_info_num_pieces(lt_torrent_info_t ti) {
    if (!ti) return 0;
    return static_cast<const torrent_info*>(ti)->num_pieces();
}

// Resume data functions
bool lt_save_resume_data_to_file(void* params, const char* path, lt_error_t* error) {
    if (!params || !path) {
        if (error) {
            error->code = -1;
            strncpy(error->message, "Invalid params or path", sizeof(error->message) - 1);
        }
        return false;
    }

    try {
        auto buf = write_resume_data_buf(*static_cast<add_torrent_params*>(params));
        std::ofstream file(path, std::ios::binary);
        if (!file) {
            if (error) {
                error->code = -1;
                strncpy(error->message, "Failed to open file", sizeof(error->message) - 1);
            }
            return false;
        }
        file.write(buf.data(), buf.size());
        file.close();
        if (error) {
            error->code = 0;
            error->message[0] = '\0';
        }
        return true;
    } catch (const std::exception& e) {
        if (error) {
            error->code = -1;
            strncpy(error->message, e.what(), sizeof(error->message) - 1);
            error->message[sizeof(error->message) - 1] = '\0';
        }
        return false;
    }
}
