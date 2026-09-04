defmodule AwradServer.Dhikr.BuiltInRegistry do
  @moduledoc "Stable UUID/catalog-key identity for the built-in dhikr catalog."

  alias AwradServer.Dhikr.Dhikr
  alias AwradServer.Repo

  @asma_path Path.expand("../../../priv/asma-ul-husna.json", __DIR__)
  @external_resource @asma_path
  @asma_entries @asma_path
                |> File.read!()
                |> Jason.decode!()
                |> Map.fetch!("names")
                |> Enum.map(fn name ->
                  %{
                    catalog_key: Map.fetch!(name, "catalog_key"),
                    id: Map.fetch!(name, "id"),
                    arabic: Map.fetch!(name, "invocation_arabic"),
                    category: "asma_ul_husna",
                    audio_count_per_play: 1,
                    sort_order: Map.fetch!(name, "number")
                  }
                end)

  @entries [
             %{
               catalog_key: "surah-ikhlas",
               id: "c88b9491-40ad-4b42-a5b8-e07c4b4d31ef",
               arabic: "قُلْ هُوَ ٱللَّهُ أَحَدٌ"
             },
             %{
               catalog_key: "tahleel",
               id: "6f04f77e-dcb6-4a29-9dc5-fcd3649c2961",
               arabic: "لَا إِلٰهَ إِلَّا ٱللَّٰهُ"
             },
             %{
               catalog_key: "ya-wahhabu",
               id: "6abe90a8-abe2-4678-a4bf-3f14323c3e8d",
               arabic: "يَا وَهَّابُ"
             },
             %{
               catalog_key: "isthighfar",
               id: "3285e014-551b-46a4-aedc-8b6664b59bc7",
               arabic: "أَسْتَغْفِرُ ٱللَّٰهَ ٱلْعَظِيمَ"
             },
             %{
               catalog_key: "swalath-al-fathimiyya",
               id: "3daf6738-face-4afc-aeca-2ab62e57a5ea",
               arabic: "اللَّهُمَّ صَلِّ عَلَى النُّورِ وَأَهْلِهِ"
             },
             %{
               catalog_key: "swalath",
               id: "f2337cb6-6d46-45fb-a193-b9e231c97bbd",
               arabic: "صَلَّى ٱللَّٰهُ عَلَىٰ مُحَمَّدٍ"
             },
             %{
               catalog_key: "swalath-sayyidina",
               id: "2a65a361-c499-41ff-b441-fc487714eacf",
               arabic: "اللَّهُمَّ صَلِّ عَلَىٰ سَيِّدِنَا مُحَمَّدٍ"
             },
             %{
               catalog_key: "swalath-al-fatih",
               id: "c94229d6-6b24-4280-ae7c-1e618fc4f1fc",
               arabic: "اللَّهُمَّ صَلِّ عَلَىٰ سَيِّدِنَا مُحَمَّدٍ الْفَاتِحِ لِمَا أُغْلِقَ"
             },
             %{
               catalog_key: "swalath-al-nariyya",
               id: "c2a59b7e-7e64-4bfe-9b0c-2d493fe01537",
               arabic: "اللَّهُمَّ صَلِّ صَلَاةً كَامِلَةً عَلَىٰ سَيِّدِنَا مُحَمَّدٍ"
             },
             %{
               catalog_key: "swalath-for-debt",
               id: "9cbb04d9-fb07-4c8f-9235-49e2ce6fc818",
               arabic: "اللَّهُمَّ صَلِّ عَلَىٰ مُحَمَّدٍ عَبْدِكَ وَرَسُولِكَ"
             },
             %{
               catalog_key: "ramadan-dhikr",
               id: "82f55daf-9f23-4d53-a10e-b60a5c90b3c8",
               arabic: "أَشْهَدُ أَنْ لَا إِلٰهَ إِلَّا ٱللَّٰهُ"
             },
             %{
               catalog_key: "ramadan-first-ten-nights",
               id: "cebda17e-2ed8-4bd6-b1f3-5dbbb29f9454",
               arabic: "اللَّهُمَّ ٱرْحَمْنِي يَا أَرْحَمَ ٱلرَّاحِمِينَ"
             },
             %{
               catalog_key: "ramadan-second-ten-nights",
               id: "b2580d39-140f-463b-a157-697997129b13",
               arabic: "اللَّهُمَّ ٱغْفِرْ لِي ذُنُوبِي يَا رَبَّ ٱلْعَالَمِينَ"
             }
           ] ++ @asma_entries

  def all, do: @entries

  def seed! do
    Enum.each(@entries, &seed_entry!/1)
  end

  defp seed_entry!(entry) do
    by_id = Repo.get(Dhikr, entry.id)
    by_key = Repo.get_by(Dhikr, catalog_key: entry.catalog_key)

    case {by_id, by_key} do
      {nil, nil} ->
        %Dhikr{id: entry.id}
        |> Dhikr.changeset(Map.put(entry, :is_custom, false))
        |> Repo.insert!()

      {%Dhikr{id: id} = dhikr, %Dhikr{id: id}} ->
        dhikr
        |> Dhikr.changeset(Map.put(entry, :is_custom, false))
        |> Repo.update!()

      {%Dhikr{catalog_key: nil} = dhikr, nil} ->
        dhikr
        |> Dhikr.changeset(Map.put(entry, :is_custom, false))
        |> Repo.update!()

      _conflict ->
        raise "built-in dhikr key/UUID conflict for #{entry.catalog_key} (#{entry.id})"
    end
  end
end
