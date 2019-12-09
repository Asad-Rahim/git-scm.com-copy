
BEGIN { # Constants.
    track_refs_prefix = "refs/remotes/";
    remote_refs_prefix = "refs/heads/";

    sha_key = "sha";
    ref_key = "ref";

    val = "val";

    out_stream_attached = "/dev/stderr";
}
BEGIN { # Globals.
    sides[1] = 1;
    sides[2] = 2;
    aside[1] = sides[2]
    aside[2] = sides[1]

    split("", origin);
    split("", prefix);
    split("", track);
    split("", remote);
}
BEGIN { # Parameters.
    write_after_line("> refs processing");
    #trace("Tracing is ON");

    if(!must_exist_branch)
        write("Deletion is blocked. Parameter must_exist_branch is empty");
        
    if(!origin_a){
        write("Error. Parameter origin_a is empty");
        exit 1002;
    }
    origin[1] = origin_a;
    origin_a = ""
    
    if(!origin_b){
        write("Error. Parameter origin_b is empty");
        exit 1003;
    }
    origin[2] = origin_b;
    origin_b = ""
    
    if(!prefix_a){
        write("Error. Parameter prefix_a is empty");
        exit 1004;
    }
    prefix[1] = prefix_a;
    prefix_a = ""
    
    if(!prefix_b){
        write("Error. Parameter prefix_b is empty");
        exit 1005;
    }
    prefix[2] = prefix_b;
    prefix_b = ""

    if(!prefix_victims){
        # Let's prevent emptiness checking all around as prefix_victims var allowed to be empty.
        prefix_victims = "{prefix_victims var is empty at the input. We use here some forbidden branch name characters to prevent messing with real branch names. .. .~^:}";
    }

    if(!newline_substitution){
        write("Error. Parameter newline_substitution is empty");
        exit 1006;
    }

    for(key in sides){
        track[key] = "track@" prefix[key];
        remote[key] = "remote@" prefix[key];
    }
}
BEGINFILE { # Preparing processing for every portion of refs.
    file_states();
}
function file_states() {
    switch (++file_num) {
        case 1:
            dest = remote[1];
            ref_prefix = remote_refs_prefix;
            break;
        case 2:
            dest = remote[2];
            ref_prefix = remote_refs_prefix;
            break;
        case 3:
            dest = track[1];
            ref_prefix = track_refs_prefix origin[1] "/";
            break;
        case 4:
            dest = track[2];
            ref_prefix = track_refs_prefix origin[2] "/";
            break;
    }
}
{ # Ref states preparation.
    if(!$2){
        # Empty input stream of an empty refs' var.
        next;
    }
        
    prefix_name_key();

    if(index($3, prefix[1]) != 1 \
        && index($3, prefix[2]) != 1 \
        && index($3, prefix_victims) != 1 \
        ){
        trace("!unexpected " $2 " (" dest ") " $1 "; branch name (" $3 ") has no allowed prefixes");

        next;
    }
    
    refs[$3][dest][sha_key] = $1;
    refs[$3][dest][ref_key] = $2;
}
function prefix_name_key() { # Generates a common key for all 4 locations of every ref.
    $3 = $2
    split($3, split_refs, ref_prefix);
    $3 = split_refs[2];
}
END { # Processing.
    dest = ""; ref_prefix = "";

    deletion_allowed = 0;
    unlock_deletion( \
        refs[must_exist_branch][remote[1]][sha_key], \
        refs[must_exist_branch][remote[2]][sha_key], \
        refs[must_exist_branch][track[1]][sha_key], \
        refs[must_exist_branch][track[2]][sha_key] \
    );
    write("Deletion " ((deletion_allowed) ? "allowed" : "blocked") " by " must_exist_branch);

    generate_missing_refs();
    declare_processing_globs();

    for(currentRef in refs){
        state_to_action( \
        currentRef, \
        refs[currentRef][remote[1]][sha_key], \
        refs[currentRef][remote[2]][sha_key], \
        refs[currentRef][track[1]][sha_key], \
        refs[currentRef][track[2]][sha_key] \
        );
    }
    actions_to_operations();
    operations_to_refspecs();
    refspecs_to_stream();
}

function unlock_deletion(rr1, rr2, lr1, lr2){
    if(!rr1)
        return;
    if(!lr1)
        return;
        
    if(rr1 != rr2)
        return;
    if(lr1 != lr2)
        return;
    if(rr1 != lr2)
        return;
    
    deletion_allowed = 1;
}
function generate_missing_refs(){
    for(ref in refs){
        if(!refs[ref][remote[1]][ref_key])
            refs[ref][remote[1]][ref_key] = remote_refs_prefix ref;
        if(!refs[ref][remote[2]][ref_key])
            refs[ref][remote[2]][ref_key] = remote_refs_prefix ref;
        if(!refs[ref][track[1]][ref_key])
            refs[ref][track[1]][ref_key] = track_refs_prefix origin[1] "/" ref;
        if(!refs[ref][track[2]][ref_key])
            refs[ref][track[2]][ref_key] = track_refs_prefix origin[2] "/" ref;
    }
}
function declare_processing_globs(){
    # Action array variables.
    # split("", a_del1); split("", a_del2);
    split("", a_ff_to1); split("", a_ff_to2);
    split("", a_solve);
    split("", a_victim_solve);

    # Operation array variables.
    split("", op_del_track);
    # split("", op_fetch1); split("", op_fetch2);
    # split("", op_push_restore1); split("", op_push_restore2);
    # split("", op_push_del1); split("", op_push_del2);
    split("", op_push_ff_to1); split("", op_push_ff_to2);
    split("", op_ff_vs_nff_to1); split("", op_ff_vs_nff_to2);
    split("", op_push_nff_to1); split("", op_push_nff_to2);
    # split("", op_fetch_post1); split("", op_fetch_post2);
    # split("", op_victim_winner_search);
}
function state_to_action(cr, rr1, rr2, lr1, lr2,    rrEqual, lrEqual, rr, lr, is_victim, action_solve_key, arr){
    rrEqual = rr1 == rr2;
    lrEqual = lr1 == lr2;
    
    if(rrEqual && lrEqual && lr1 == rr2){
        # Nothing to change for the current branch.

        return;
    }

    rr = rrEqual ? rr1 : "# remote refs are not equal #";

    if(rrEqual && !rr){
        # As we here this means that remote repos don't know the branch but gitSync knows it somehow.
        # This behavior supports independents of gitSync from its remoter repos. I.e. you can replace them at once, as gitSync will be the source of truth.
        # But if you don't run gitSync for a while and have deleted the branch on both side repos manually then gitSync will recreate it.
        # Re-delete the branch and use gitSync. Silly))

        trace(cr " action-restore on both remotes; is unknown");
        a_restore[cr];

        return;
    }

    if(rrEqual){
        if(rr != lr1){
            # Possibly gitSync or the network was interrupted.
            trace(cr " action-fetch from " origin[1] "; track ref is " ((lr1) ? "outdated" : "unknown"));
            a_fetch[1][cr];
        }
        if(rr != lr2){
            # Possibly gitSync or the network was interrupted.
            trace(cr " action-fetch from " origin[2] "; track ref is " ((lr2) ? "outdated" : "unknown"));
            a_fetch[2][cr];
        }

        return;
    }

    # ! All further actions suppose that remote refs are not equal.

    lr = lrEqual ? lr1 : "# track refs are not equal #";

    is_victim = index(cr, prefix_victims) == 1;
    action_solve_key = is_victim ? "action-victim-solve" : "action-solve";

    if(lrEqual && !lr){
        trace(cr " " action_solve_key " on both remotes; is not tracked");
        set_solve_action(is_victim, cr);

        return;
    }

    if(lrEqual){
        if(!rr1 && rr2 == lr){
            if(deletion_allowed){
                trace(cr " action-del on " origin[2] "; is disappeared from " origin[1]);
                a_del[2][cr];
            }else{
                trace(cr " " action_solve_key "-as-del-blocked on " origin[2] "; is disappeared from " origin[1] " and deletion is blocked");
                set_solve_action(is_victim, cr);
            }

            return;
        }
        if(!rr2 && rr1 == lr){
            if(deletion_allowed){
                trace(cr " action-del on " origin[1] "; is disappeared from " origin[2]);
                a_del[1][cr];
            }else{
                trace(cr " " action_solve_key "-as-del-blocked on " origin[1] "; is disappeared from " origin[2] " and deletion is blocked");
                set_solve_action(is_victim, cr);
            }

            return;
        }
    }

    if(lrEqual && !is_victim){
        if(rr1 == lr && rr2 != lr){
            trace(cr " action-fast-forward; outdated on " origin[1]);
            a_ff_to1[cr];

            return;
        }
        if(rr2 == lr && rr1 != lr){
            trace(cr " action-fast-forward; outdated on " origin[2]);
            a_ff_to2[cr];

            return;
        }
    }

    trace(cr " " action_solve_key "-all-others; is different track or/and remote branch commits");
    set_solve_action(is_victim, cr);
}
function set_solve_action(is_victim, ref){
    if(is_victim){
        a_victim_solve[ref];
    }else{
        a_solve[ref];
    }
}
function actions_to_operations(    side, ref, owns_side, victims_push_requested){
    for(ref in a_restore){
        for(side in sides){
            if(!refs[ref][track[side]][sha_key]){
                continue;
            }
            op_push_restore[side][ref];
            #op_fetch_post[side][ref];
        }
    }

    for(side in a_fetch){
        for(ref in a_fetch[side]){
            op_fetch[side][ref]
        }
    }

    for(side in a_del){
        for(ref in a_del[side]){
            op_del_track[ref];
            op_push_del[side][ref];
        }
    }

    # Warning! We need post fetching here because a ref's change may be not a FF-change. And without the post fetch the sync will not be resolved ever.
    # This is a case when a sync-collision will be solved with two sync passes.
    for(ref in a_ff_to1){
        op_fetch[2][ref];
        
        op_ff_vs_nff_to1[ref];
        #op_push_ff_to1[ref];
        #op_fetch_post[1][ref];
    }
    for(ref in a_ff_to2){
        op_fetch[1][ref];
        
        op_ff_vs_nff_to2[ref];
        #op_push_ff_to2[ref];
        #op_fetch_post[2][ref];
    }

    for(ref in a_victim_solve){

        # Update outdated or missing track refs for existing remote refs.
        if(refs[ref][remote[1]][sha_key]){
            if(refs[ref][remote[1]][sha_key] != refs[ref][track[1]][sha_key]){
                op_fetch[1][ref];
            }
        }
        if(refs[ref][remote[2]][sha_key]){
            if(refs[ref][remote[2]][sha_key] != refs[ref][track[2]][sha_key]){
                op_fetch[2][ref];
            }
        }

        # Update non-existing remote refs.
        if(!refs[ref][remote[1]][sha_key] && refs[ref][remote[2]][sha_key]){
            victims_push_requested = 1;
            op_push_nff_to1[ref];
            #op_fetch_post[1][ref];
        }
        if(!refs[ref][remote[2]][sha_key] && refs[ref][remote[1]][sha_key]){
            victims_push_requested = 1;
            op_push_nff_to2[ref];
            #op_fetch_post[2][ref];
        }

        # Stop if non-existing remote refs will be updated.
        if(victims_push_requested){
            victims_push_requested = 0;
            continue;
        }

        op_victim_winner_search[ref];
    }

    split("", owns_side);
    for(ref in a_solve){
        owns_side[1] = index(ref, prefix[1]) == 1;
        owns_side[2] = index(ref, prefix[2]) == 1;

        if(!owns_side[1] && !owns_side[2]){
            trace("operation-solve; Ignoring " ref " as it has no allowed prefixes " prefix[1] " or " prefix[2])
            continue;
        }

        if(owns_side[1]){
            if(refs[ref][remote[1]][sha_key]){
                if(refs[ref][remote[1]][sha_key] != refs[ref][track[1]][sha_key]){
                    op_fetch[1][ref];
                }
                op_push_nff_to2[ref];
                #op_fetch_post[2][ref];
            } else if(refs[ref][remote[2]][sha_key]){
                if(refs[ref][remote[2]][sha_key] != refs[ref][track[2]][sha_key]){
                    op_fetch[2][ref];
                }
                op_push_nff_to1[ref];
                #op_fetch_post[1][ref];
            }
        }
        if(owns_side[2]){
            if(refs[ref][remote[2]][sha_key]){
                if(refs[ref][remote[2]][sha_key] != refs[ref][track[2]][sha_key]){
                    op_fetch[2][ref];
                }
                op_push_nff_to1[ref];
                #op_fetch_post[1][ref];
            } else if(refs[ref][remote[1]][sha_key]){
                if(refs[ref][remote[1]][sha_key] != refs[ref][track[1]][sha_key]){
                    op_fetch[1][ref];
                }
                op_push_nff_to2[ref];
                #op_fetch_post[2][ref];
            }
        }
    }
}
function operations_to_refspecs(    side, ref){
    { # op_del_track
        for(ref in op_del_track){
            if(refs[ref][track[1]][sha_key]){
                out_del = out_del "  " origin[1] "/" ref;
            }
            if(refs[ref][track[2]][sha_key]){
                out_del = out_del "  " origin[2] "/" ref;
            }
        }
    }
    { # op_fetch1, op_fetch2
        for(side in op_fetch){
            for(ref in op_fetch[side]){
                out_fetch[side] = out_fetch[side] "  +" refs[ref][remote[side]][ref_key] ":" refs[ref][track[side]][ref_key];
            }
        }
    }

    for(side in op_push_restore){
        for(ref in op_push_restore[side]){
            out_push[side] = out_push[side] "  +" refs[ref][track[side]][ref_key] ":" refs[ref][remote[side]][ref_key];
        }
    }

    for(side in op_push_del){
        for(ref in op_push_del[side]){
            out_push[side] = out_push[side] "  +:" refs[ref][remote[side]][ref_key];
            
            append_by_val(out_notify_del, prefix[side]  " | deletion | "  refs[ref][remote[side]][ref_key]  "   "  refs[ref][remote[side]][sha_key]);
        }
    }

    { # op_push_ff_to1, op_push_ff_to2
        for(ref in op_push_ff_to1){
            out_push[1] = out_push[1] "  " refs[ref][track[2]][ref_key] ":" refs[ref][remote[1]][ref_key];
        }
        for(ref in op_push_ff_to2){
            out_push[2] = out_push[2] "  " refs[ref][track[1]][ref_key] ":" refs[ref][remote[2]][ref_key];
        }
    }
    { # op_push_nff_to1, op_push_nff_to2
        for(ref in op_push_nff_to1){
            out_push[1] = out_push[1] "  +" refs[ref][track[2]][ref_key] ":" refs[ref][remote[1]][ref_key];
        }
        for(ref in op_push_nff_to2){
            out_push[2] = out_push[2] "  +" refs[ref][track[1]][ref_key] ":" refs[ref][remote[2]][ref_key];
        }

        for(ref in op_push_nff_to1){
            if(refs[ref][remote[1]][sha_key]){
                append_by_val(out_notify_solving, prefix[1]  " | conflict-solving | "  refs[ref][remote[1]][ref_key]  "   "  refs[ref][remote[1]][sha_key]);
            }
        }
        for(ref in op_push_nff_to2){
            if(refs[ref][remote[2]][sha_key]){
                append_by_val(out_notify_solving, prefix[2]  " | conflict-solving | "  refs[ref][remote[2]][ref_key]  "   "  refs[ref][remote[2]][sha_key]);
            }
        }
    }
    set_ff_vs_nff_push_data();
    set_victim_data();

    # Post fetching is used to fix FF-updating fails by two pass syncing. The fail appears if NFF updating of an another side brach was considered as FF updating.
    for(side in op_fetch_post){
        for(ref in op_fetch_post[side]){
            out_post_fetch[side] = out_post_fetch[side] "  +" refs[ref][remote[side]][ref_key] ":" refs[ref][track[side]][ref_key];
        }
    }
}
function set_ff_vs_nff_push_data(    descendant_sha, ancestor_sha){
    for(ref in op_ff_vs_nff_to1){
        # 1 is an ancestor, update target.
        # 2 is a descendant (possibly), update source.
        ancestor_sha = refs[ref][remote[1]][sha_key] ? refs[ref][remote[1]][sha_key] : ("no sha for " remote[1]);
        descendant_sha = refs[ref][remote[2]][sha_key] ? refs[ref][remote[2]][sha_key] : ("no sha for " remote[2]);

        append_by_side(out_ff_vs_nff_data, 1, "ff-vs-nff " ref " " ancestor_sha " " descendant_sha);
        
        # --is-ancestor <ancestor> <descendant>
        append_by_side(out_ff_vs_nff_data, 1, "git merge-base --is-ancestor " refs[ref][track[1]][ref_key] " " refs[ref][track[2]][ref_key] " && echo ff || echo nff");
        
        append_by_side(out_ff_vs_nff_data, 1, refs[ref][track[2]][ref_key] ":" refs[ref][remote[1]][ref_key]);
    }
    for(ref in op_ff_vs_nff_to2){
        # 2 is an ancestor, update target.
        # 1 is a descendant (possibly), update source.
        ancestor_sha = refs[ref][remote[2]][sha_key] ? refs[ref][remote[2]][sha_key] : ("no sha for " remote[2]);
        descendant_sha = refs[ref][remote[1]][sha_key] ? refs[ref][remote[1]][sha_key] : ("no sha for " remote[1]);

        append_by_side(out_ff_vs_nff_data, 2, "ff-vs-nff " ref " " ancestor_sha " " descendant_sha);
        
        # --is-ancestor <ancestor> <descendant>
        append_by_side(out_ff_vs_nff_data, 2, "git merge-base --is-ancestor " refs[ref][track[2]][ref_key] " " refs[ref][track[1]][ref_key] " && echo ff || echo nff");
        
        append_by_side(out_ff_vs_nff_data, 2, refs[ref][track[1]][ref_key] ":" refs[ref][remote[2]][ref_key]);
    }
}
function set_victim_data(    ref, sha1, sha2){
    for(ref in op_victim_winner_search){
        # We expects that "no sha" cases will be processed in by solving actions.
        # But this approach with variables helped to solve a severe. It makes code more resilient.
        sha1 = refs[ref][remote[1]][sha_key] ? refs[ref][remote[1]][sha_key] : ("no sha for " remote[1]);
        sha2 = refs[ref][remote[2]][sha_key] ? refs[ref][remote[2]][sha_key] : ("no sha for " remote[2]);

        append_by_val(out_victim_data, "victim " ref " " sha1 " " sha2);
        
        append_by_val(out_victim_data, "git rev-list " refs[ref][track[1]][ref_key] " " refs[ref][track[2]][ref_key] " --max-count=1");
        
        append_by_val(out_victim_data, "  +" refs[ref][track[1]][ref_key] ":" refs[ref][remote[2]][ref_key]);
        append_by_val(out_victim_data, "  +" refs[ref][track[2]][ref_key] ":" refs[ref][remote[1]][ref_key]);
    }
}

function append_by_side(host, side_id, addition){
    host[side_id] = host[side_id] (host[side_id] ? newline_substitution : "") addition;
}
function append_by_val(host, addition){
    host[val] = host[val] (host[val] ? newline_substitution : "") addition;
}

function refspecs_to_stream(){
    # 0
    print out_del;
    # 1
    print out_fetch[1];
    # 2
    print out_fetch[2];
    # 3
    print out_ff_vs_nff_data[1];
    # 4
    print out_ff_vs_nff_data[2];
    # 5
    print out_victim_data[val];
    # 6
    print out_push[1];
    # 7
    print out_push[2];
    # 8
    print out_post_fetch[1];
    # 9
    print out_post_fetch[2];
    # 10
    print out_notify_del[val];
    # 11
    print out_notify_solving[val];

    # 12
    # Must print finishing line otherwise previous empty lines will be ignored by mapfile command in bash.
    print "{[end-of-results]}"
}


function write(msg){
    print msg >> out_stream_attached;
}
function write_after_line(msg){
    write("\n" msg);
}
function trace(msg){
    if(!trace_on)
        return;

    if(!msg){
        print "|" >> out_stream_attached;
        return;
    }

    print "|" msg >> out_stream_attached;
}
function trace_header(msg){
    trace();
    trace(msg);
    trace();
}
function trace_after_line(msg){
    trace();
    trace(msg);
}
function trace_line(msg){
    trace(msg);
    trace();
}
function dTrace(msg){
    if(0)
        return;

    trace("|" msg)
}

END{ # Disposing.
    write("> refs processing end");

    # Possibly the close here is excessive.
    #https://www.gnu.org/software/gawk/manual/html_node/Close-Files-And-Pipes.html#Close-Files-And-Pipes
    close(out_stream_attached);
}
