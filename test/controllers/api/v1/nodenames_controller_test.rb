require "test_helper"

class Api::V1::NodenamesControllerTest < ActionController::TestCase
  setup do
    request.env["HTTP_AUTHORIZATION"] = "Token token=\"POST_ADMINISTRATOR_TOKEN\""
  end

  test "correct token should be provided" do
    request.env["HTTP_AUTHORIZATION"] = "incorrect token"
    post(:create)
    assert_response :unauthorized
  end

  test "file should be provided" do
    post(:create, { network_vid: "6670" })
    assert_equal("error", @response.body)
  end

  test "network_vid should be provided" do
    nodename_empty = fixture_file_upload(
      "nodenames/empty.doc",
      "application/octet-stream"
    )
    post(:create, { file: nodename_empty })
    assert_equal("error", @response.body)
  end

  test "create" do
    Network.destroy_all

    # 00_initial (:add)
    initial_nodename = fixture_file_upload(
      "nodenames/00_initial.doc",
      "application/octet-stream"
    )
    post(:create, { file: initial_nodename, network_vid: "6670" })
    expected_ncc_nodes = [
      {
        type: "CurrentNccNode",
        vid: "0x1a0e000a",
        name: "coordinator1",
        enabled: true,
        category: "server",
        abonent_number: "0000",
        server_number: "0001",
        creation_date_accuracy: false,
      },
      {
        type: "CurrentNccNode",
        vid: "0x1a0e000b",
        name: "administrator",
        enabled: true,
        category: "client",
        abonent_number: "0001",
        server_number: "0001",
        creation_date_accuracy: false,
      },
    ]
    assert_ncc_nodes_should_be expected_ncc_nodes

    # 01_added_client1 (:add)
    added_client1_nodename = fixture_file_upload(
      "nodenames/01_added_client1.doc",
      "application/octet-stream"
    )
    post(:create, { file: added_client1_nodename, network_vid: "6670" })
    expected_ncc_nodes.push(
      {
        type: "CurrentNccNode",
        vid: "0x1a0e000c",
        name: "client1",
        enabled: true,
        category: "client",
        abonent_number: "0002",
        server_number: "0001",
        creation_date_accuracy: true,
      },
    )
    assert_ncc_nodes_should_be expected_ncc_nodes

    # 02_renamed_client1 (:change)
    renamed_client1_nodename = fixture_file_upload(
      "nodenames/02_renamed_client1.doc",
      "application/octet-stream"
    )
    post(:create, { file: renamed_client1_nodename, network_vid: "6670" })
    expected_ncc_nodes.change_where({ vid: "0x1a0e000c" },
      {
        name: "client1-renamed1",
        enabled: false,
      }
    )
    expected_ncc_nodes_ascendants = [
      {
        descendant_type: "CurrentNccNode",
        descendant_vid: "0x1a0e000c",
        name: "client1",
        enabled: true,
      }
    ]
    assert_ncc_nodes_should_be expected_ncc_nodes
    assert_ncc_nodes_ascendants_should_be expected_ncc_nodes_ascendants

    # 03_added_coordinator2 (:add)
    added_coordinator2_nodename = fixture_file_upload(
      "nodenames/03_added_coordinator2.doc",
      "application/octet-stream"
    )
    post(:create, { file: added_coordinator2_nodename, network_vid: "6670" })
    expected_ncc_nodes.push(
      {
        type: "CurrentNccNode",
        vid: "0x1a0e000d",
        name: "coordinator2",
        enabled: true,
        category: "server",
        abonent_number: "0000",
        server_number: "0002",
        creation_date_accuracy: true,
      },
    )
    expected_ncc_nodes.change_where({ vid: "0x1a0e000c" }, { enabled: true })
    expected_ncc_nodes_ascendants.push(
      {
        descendant_type: "CurrentNccNode",
        descendant_vid: "0x1a0e000c",
        enabled: false,
      }
    )
    assert_ncc_nodes_should_be expected_ncc_nodes
    assert_ncc_nodes_ascendants_should_be expected_ncc_nodes_ascendants

    # 04_client1_moved_to_coordinator2 (:change)
    client1_moved_to_coordinator2_nodename = fixture_file_upload(
      "nodenames/04_client1_moved_to_coordinator2.doc",
      "application/octet-stream"
    )
    post(:create, { file: client1_moved_to_coordinator2_nodename, network_vid: "6670" })
    expected_ncc_nodes.change_where({ vid: "0x1a0e000c" },
      {
        abonent_number: "0001",
        server_number: "0002",
      }
    )
    expected_ncc_nodes_ascendants.push(
      {
        descendant_type: "CurrentNccNode",
        descendant_vid: "0x1a0e000c",
        abonent_number: "0002",
        server_number: "0001",
      }
    )
    assert_ncc_nodes_should_be expected_ncc_nodes
    assert_ncc_nodes_ascendants_should_be expected_ncc_nodes_ascendants

    # 05_client1_disabled (:change)
    client1_disabled_nodename = fixture_file_upload(
      "nodenames/05_client1_disabled.doc",
      "application/octet-stream"
    )
    post(:create, { file: client1_disabled_nodename, network_vid: "6670" })
    expected_ncc_nodes.change_where({ vid: "0x1a0e000c" }, { enabled: false })
    expected_ncc_nodes_ascendants.push(
      {
        descendant_type: "CurrentNccNode",
        descendant_vid: "0x1a0e000c",
        enabled: true,
      }
    )
    assert_ncc_nodes_should_be expected_ncc_nodes
    assert_ncc_nodes_ascendants_should_be expected_ncc_nodes_ascendants

    # 06_added_node_from_ignoring_network
    # (nothing should change)
    Settings.networks_to_ignore = "6671"
    added_node_from_ignoring_network_nodename = fixture_file_upload(
      "nodenames/06_added_node_from_ignoring_network.doc",
      "application/octet-stream"
    )
    post(:create, { file: added_node_from_ignoring_network_nodename, network_vid: "6670" })
    assert_ncc_nodes_should_be expected_ncc_nodes
    assert_ncc_nodes_ascendants_should_be expected_ncc_nodes_ascendants

    # 07_added_internetworking_node_from_network_we_admin
    # (nothing should change)
    # network we admin is network for such we have nodename
    # first_network_we_admin = Network.find_by(network_vid: "6670")
    another_network_we_admin = Network.new(network_vid: "6672")
    another_network_we_admin.save!
    Nodename.push(hash: {}, belongs_to: another_network_we_admin)
    added_internetworking_node_we_admins_nodename = fixture_file_upload(
      "nodenames/07_added_internetworking_node_we_admins.doc",
      "application/octet-stream"
    )
    post(:create, { file: added_internetworking_node_we_admins_nodename, network_vid: "6670" })
    assert_ncc_nodes_should_be expected_ncc_nodes
    assert_ncc_nodes_ascendants_should_be expected_ncc_nodes_ascendants
    # cleaning up
    another_network_we_admin.destroy
    Nodename.thread(another_network_we_admin).destroy_all

    # 08_group_changed
    # (group isn't in NccNode.props_from_nodename, so there are souldn't be any changes)
    group_changed_nodename = fixture_file_upload(
      "nodenames/08_group_changed.doc",
      "application/octet-stream"
    )
    post(:create, { file: group_changed_nodename, network_vid: "6670" })
    assert_ncc_nodes_should_be expected_ncc_nodes
    assert_ncc_nodes_ascendants_should_be expected_ncc_nodes_ascendants

    # 09_client1_removed (:remove)
    client1_removed_nodename = fixture_file_upload(
      "nodenames/09_client1_removed.doc",
      "application/octet-stream"
    )
    post(:create, { file: client1_removed_nodename, network_vid: "6670" })
    expected_ncc_nodes.change_where({ vid: "0x1a0e000c" }, { type: "DeletedNccNode" })
    expected_ncc_nodes_ascendants.change_where(
      {
        descendant_type: "CurrentNccNode",
        descendant_vid: "0x1a0e000c",
      },
      {
        descendant_type: "DeletedNccNode",
      }
    )
    assert_ncc_nodes_should_be expected_ncc_nodes
    assert_ncc_nodes_ascendants_should_be expected_ncc_nodes_ascendants
  end
end
